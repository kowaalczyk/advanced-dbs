import logging
import os
import pickle
import sys
import typing as T
from queue import Queue
from multiprocessing import Pool, cpu_count
from xml.dom import pulldom
from xml.sax import make_parser
from xml.sax.handler import feature_external_ges
import gc

from tqdm import tqdm

from pydblp.db import insert_publication_data, batch_insert_data
from pydblp.parsing import parse_dependency, parse_data, parse_secondary_dependency, get_node_text
from pydblp.translation import SECONDARY_DEPS_TAGNAMES, PUBLICATION_TAGNAMES, ATTR_TO_ATTR_MAPPING, DEPS_TAGNAMES, \
    DATA_TAGNAMES, TAG_TO_ATTR_MAPPING


n_processes = min(14, cpu_count()*2)

log = logging.getLogger(__name__)


def insert_publication_data_onearg(args):
    return insert_publication_data(*args)


def load_dblp(
        process_pool: Pool,
        filename: str,
        expected_event_count: T.Optional[int] = 248393285
) -> None:
    os.chdir(os.path.dirname(filename))  # so that relative reference to dtd file can be read by XML parser

    parser = make_parser()
    parser.setFeature(feature_external_ges, True)

    doc = pulldom.parse(os.path.basename(filename), parser=parser, bufsize=2 ** 14)

    n_parsed_publications = 0
    n_total_publciations = 0
    elements_failed_to_parse = list()
    failed_flag = False

    publications_to_insert = list()
    async_results = Queue()
    n_db_uploads = 0
    n_db_errors = 0

    current_publ_cat = None
    current_key = None
    current_deps = None
    current_publication_attrs = None
    current_data = None
    current_secondary_deps = None

    if not gc.isenabled():
        gc.enable()

    t = tqdm(doc, total=expected_event_count)

    for event, node in t:
        if event == pulldom.START_ELEMENT:
            if failed_flag is True:
                continue
            if node.tagName in PUBLICATION_TAGNAMES:
                if current_publ_cat is not None:
                    raise ValueError(f"Overlapping top-level tags: current={current_publ_cat}, new={node.tagName}")
                current_publ_cat = node.tagName
                current_deps = list()
                current_data = list()
                current_publication_attrs = dict()
                current_secondary_deps = list()
                for k, v in node.attributes.items():
                    if k == 'key':
                        current_key = v
                    elif k in ATTR_TO_ATTR_MAPPING.keys():
                        mapped = ATTR_TO_ATTR_MAPPING[k](v)
                        current_publication_attrs.update(**mapped)
                    else:
                        log.warning(f"Unhandled XML attribute \"{k}\" for {current_publ_cat}")
            else:
                if current_publ_cat is None:
                    log.warning(f"Omitting top-level tag: {node.tagName}")
                else:
                    # try:
                    if node.tagName in DEPS_TAGNAMES.keys():
                        doc.expandNode(node)
                        new_dep = parse_dependency(node)
                        current_deps.append(new_dep)
                    elif node.tagName in DATA_TAGNAMES.keys():
                        doc.expandNode(node)
                        new_data = parse_data(node, current_key)
                        current_data.append(new_data)
                    elif node.tagName in SECONDARY_DEPS_TAGNAMES.keys():
                        doc.expandNode(node)
                        person, dependency_name, dependency_attrs = parse_secondary_dependency(node)
                        current_secondary_deps.append(
                            (person, dependency_name, dependency_attrs)
                        )
                    elif node.tagName in TAG_TO_ATTR_MAPPING.keys():
                        doc.expandNode(node)
                        tag_content = get_node_text(node)
                        mapped = TAG_TO_ATTR_MAPPING[node.tagName](tag_content)
                        current_publication_attrs.update(**mapped)
                    else:
                        raise ValueError(f"Unhandled XML child tag <{node.tagName}> for {current_publ_cat}")
                    # except Exception as e:
                    #     elements_failed_to_parse.append({
                    #         'exception': e,
                    #         'current_key': current_key,
                    #         'current_publ_cat': current_publ_cat,
                    #         'current_deps': current_deps,
                    #         'current_publication_attrs': current_publication_attrs,
                    #         'current_data': current_data,
                    #         'current_secondary_deps': current_secondary_deps,
                    #     })
                    #     log.warning(e)
                    #     failed_flag = True

        elif event == pulldom.END_ELEMENT and node.tagName in PUBLICATION_TAGNAMES:
            n_total_publciations += 1

            if failed_flag is False:
                # save all parsed elements to db

                # variant 1:
                # insert_publication_data(
                #     current_key,
                #     current_publ_cat,
                #     current_publication_attrs,
                #     current_deps,
                #     current_data,
                #     current_secondary_deps,
                # )

                # variant 2:
                # process_pool.apply_async(
                #     insert_publication_data,
                #     (
                #         current_key,
                #         current_publ_cat,
                #         current_publication_attrs,
                #         current_deps,
                #         current_data,
                #         current_secondary_deps
                #     )
                # )

                # variant 3:
                publications_to_insert.append((
                        current_key,
                        current_publ_cat,
                        current_publication_attrs,
                        current_deps,
                        current_data,
                        current_secondary_deps,
                ))
                n_parsed_publications += 1

            else:
                failed_flag = False

            # reset data for next iteration to prevent errors
            current_publ_cat = None
            current_key = None
            current_deps = None
            current_publication_attrs = None
            current_data = None
            current_secondary_deps = None

            if n_parsed_publications % n_processes == 0:
                # variant A part 1:
                # database insertions are batched to better distribute load among processes
                res = process_pool.map_async(
                    insert_publication_data_onearg,
                    publications_to_insert,
                    chunksize=(len(publications_to_insert) // n_processes) + 1
                )
                async_results.put(res)
                publications_to_insert = list()
                pass

            if n_total_publciations % (min(2**12, 4 * n_processes)) == 0:
                # variant B:
                # try:
                # batch_insert_data(publications_to_insert)
                # n_db_uploads += 1
                # except Exception as e:
                #     log.warning(e)
                #     n_db_errors += 1
                # publications_to_insert = list()

                # variant A part 2:
                # garbage collection an iteration ~10x so we don't do it every time
                res = async_results.get()
                try:
                    _ = res.get()
                    n_db_uploads += 1
                except Exception as e:
                    log.warning(e)
                    n_db_errors += 1
                gc.collect()

            t.set_postfix_str(
                "total={}, parsed={}, failed={}, db_inserted={}, db_failed={}".format(
                    n_total_publciations,
                    n_parsed_publications,
                    n_total_publciations - n_parsed_publications,
                    n_db_uploads,
                    n_db_errors
                ),
                refresh=False
            )

    while not async_results.empty():
        res = async_results.get()
        try:
            _ = res.get()
            n_db_uploads += 1
        except Exception as e:
            log.warning(e)
            n_db_errors += 1
    gc.collect()

    log.info("Data upload complete: {}/{} successful ({} failed)".format(
        n_parsed_publications, n_total_publciations, n_total_publciations - n_parsed_publications
    ))
    if n_parsed_publications < n_total_publciations:
        pickle.dump(elements_failed_to_parse, open("failed.pkl", "wb"))


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    # logging.basicConfig(level=logging.INFO)

    if len(sys.argv) > 1:
        filename = sys.argv[1]
    else:
        filename = "../data/dblp.xml"
    with Pool(n_processes) as pool:
        load_dblp(pool, filename)
