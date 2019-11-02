import csv
import gc
import logging
import os
import sys
import time
import typing as T
from multiprocessing import cpu_count, Pool
from xml.dom import pulldom
from xml.dom.minidom import Element
from xml.sax import make_parser
from xml.sax.handler import feature_external_ges

import pandas as pd
from tqdm import tqdm


log = logging.getLogger(__name__)


""" XML Tagnames related to the various Publication categories """
PUBLICATION_TAGNAMES = {
    'article',
    'inproceedings',
    'proceedings',
    'book',
    'incollection',
    'phdthesis',
    'mastersthesis',
    'www',
}

""" Set of XML tags that should use default mapper """
DEFAULT_MAPPING_TAGS = {
    'booktitle',
    'cdrom',
    'journal',
    'number',
    'title',
}

""" Set of XML tags that should use integer mapper """
INT_MAPPING_TAGS = {
    'month',
    'volume',
    'year',
}


def get_default_mapper(s: str) -> T.Callable:
    """
    Get the default (string to string) mapper for a given object attribute
    :param s: attribute name
    :return: function mapping value of attribute to { attribute: value } dict
    """
    def mapper(val: str) -> T.Dict[str, str]:
        return {s: val}

    return mapper


def get_int_mapper(s: str) -> T.Callable:
    """
    Get the type checked (integer) mapper for a given object attribute
    :param s: attribute name
    :return: function mapping value of attribute to { attribute: int(value) } dict
    """
    def mapper(val: str) -> T.Dict[str, T.Optional[int]]:
        try:
            mapped =  {s: int(val)}
        except ValueError:
            mapped = {s: None}
        return mapped

    return mapper


def page_mapper(val: str) -> T.Dict[str, T.Optional[str]]:
    try:
        separated = val.split("-")
        if len(separated) == 1:
            page = separated[0]
            return {'pages': f"[{int(page)},{int(page)}]"}
        else:
            return {'pages': f"[{int(separated[0])},{int(separated[1])}]"}
    except ValueError:
        # for now, we drop values that are not stored as integer or integer range
        return {'pages': None}


""" Mapping XML tags to DB attributes """
TAG_TO_ATTR_MAPPING = {
    'pages': page_mapper,
    **{k: get_default_mapper(k) for k in DEFAULT_MAPPING_TAGS},
    **{k: get_int_mapper(k) for k in INT_MAPPING_TAGS}
}

""" Mapping XML attributes to DB attributes """
ATTR_TO_ATTR_MAPPING = {
    'publtype': get_default_mapper('type'),
    **{a: get_default_mapper(a) for a in {'cdate', 'mdate'}}
    # key is stored separately to easily pass to dependent models
}

""" Mapping: XML tag name, attribute name in DB, table name in DB """
GENERIC_DATA = [
    ('ee', 'url', 'electronic_edition'),
    ('crossref', 'str', 'crossref'),
    ('cite', 'str', 'cite'),
    ('note', 'note', 'note'),
    ('url', 'url', 'url'),
    ('isbn', 'isbn', 'isbn'),
]

GENERIC_DATA_TABLES = set(gd[-1] for gd in GENERIC_DATA)


def get_node_text(node: Element) -> str:
    """
    Returns entire XML contained within a node (without beginning and opening tag) as a string.
    :param node:
    :return: node text
    """
    return node.toxml().replace(f"<{node.tagName}>", "").replace(f"</{node.tagName}>", "")


class TagParser(object):
    """  Abstract base class for parsing XML documents with progressbar, data validation, etc. """
    _filtered_tags: T.Set[str] = set()  # other tags will be ignored
    _tqdm_prefix: str = "tag_parser"

    def __init__(self, filename, use_pbar: bool = True):
        self.n_parsed_publications = 0
        self.n_total_publciations = 0
        self.elements_failed_to_parse = list()
        self.failed_flag = False
        self.current_publication_key = None

        parser = make_parser()
        parser.setFeature(feature_external_ges, True)
        self.doc = pulldom.parse(
            os.path.basename(filename), parser=parser, bufsize=2 ** 14
        )
        if use_pbar:
            self.t = tqdm(self.doc, total=expected_event_count)
        else:
            self.t = self.doc
        self.pbar = use_pbar

    def _handle_filtered_tag(self, event, node: Element):
        """
        Use to parse specific subtags for a given top-level publication key
        :param event:
        :param node:
        :return:
        """
        raise NotImplementedError()

    def _post_call(self):
        """
        Use to some final transforms and return values in a desired format when calling the class.
        :return:
        """
        raise NotImplementedError()

    def _conclude_publication(self):
        """ Called after an entire single publication is processed, override to add custom logic. """
        if self.failed_flag is True:
            self.elements_failed_to_parse.append(self.current_publication_key)
            self.failed_flag = False
        else:
            self.n_parsed_publications += 1

        self.n_total_publciations += 1
        self.current_publication_key = None
        if self.pbar:
            self.t.set_postfix_str(
                "{}: total={}, parsed={}, failed={}".format(
                    self.__class__._tqdm_prefix,
                    self.n_total_publciations,
                    self.n_parsed_publications,
                    self.n_total_publciations - self.n_parsed_publications
                ),
                refresh=False
            )

    def __call__(self):
        """ Loads and parses entire XML document, override to add custom logic. """
        for event, node in self.t:
            if event == pulldom.START_ELEMENT:
                if self.failed_flag is True:
                    continue

                if node.tagName in PUBLICATION_TAGNAMES:
                    if self.current_publication_key is not None:
                        raise ValueError(f"Overlapping top-level tags at key: {self.current_publication_key}")
                    for k, v in node.attributes.items():
                        if k == 'key':
                            self.current_publication_key = v
                    if self.current_publication_key is None:
                        raise ValueError(f"Publication without a key: {node}")
                else:
                    if self.current_publication_key is None:
                        log.warning(f"Omitting top-level tag: {node.tagName}")
                    elif node.tagName in self.__class__._filtered_tags:
                        self.doc.expandNode(node)
                        self._handle_filtered_tag(event, node)
                    else:
                        continue

            elif event == pulldom.END_ELEMENT and node.tagName in PUBLICATION_TAGNAMES:
                self._conclude_publication()
                # TODO: Remove this after finished debugging
                if self.n_parsed_publications > 10**4:
                    break
        if self.pbar:
            self.t.close()
        return self._post_call()


def parse_person_dependency(node: Element) -> T.Tuple[T.Dict[str, T.Any], T.Dict[str, T.Any]]:
    tag_attrs = {k: v for k, v in node.attributes.items()}
    tag_content = get_node_text(node)

    person_attrs = {
        'full_name': tag_content,
        'orcid': tag_attrs.get('orcid'),
    }
    relation_attrs = {
        k: v for k, v in tag_attrs.items() if k != 'orcid'
    }
    return person_attrs, relation_attrs


class PersonTagParser(TagParser):
    """ Parses Editor and Author tags into person, editor and author tables. """

    _tqdm_prefix: str = "person_parser"
    _filtered_tags = {'author', 'editor'}
    _person_id = dict()  # (full_name, orcid) => id
    _author_dfs = list()
    _editor_dfs = list()
    _person_dfs = list()
    # person_df = pd.DataFrame(columns=['full_name', 'orcid'])

    def _handle_filtered_tag(self, event, node: Element):
        person_attrs, realtion_attrs = parse_person_dependency(node)

        try:
            person_id = self.__class__._person_id[(person_attrs['full_name'], person_attrs['orcid'])]
        except KeyError:
            person_id = len(self.__class__._person_dfs)
            self.__class__._person_id[(person_attrs['full_name'], person_attrs['orcid'])] = person_id
            self.__class__._person_dfs.append(
                pd.DataFrame(person_attrs, index=[person_id])
            )

        realtion_attrs['publication_key'] = self.current_publication_key
        realtion_attrs['person_id'] = person_id

        if node.tagName == 'author':
            self.__class__._author_dfs.append(pd.DataFrame(realtion_attrs, index=[1]))
        elif node.tagName == 'editor':
            self.__class__._editor_dfs.append(pd.DataFrame(realtion_attrs, index=[1]))
        else:
            raise ValueError(f"Expected person or editor at key: {self.current_publication_key}")

    def _post_call(self):
        self.__class__.person_df = pd.concat(self.__class__._person_dfs, axis='index')

        if len(self.__class__._author_dfs) > 0:
            self.__class__.author_df = pd.concat(self.__class__._author_dfs, axis='index', ignore_index=True)
        else:
            self.__class__.author_df = pd.DataFrame(columns=['person_id', 'publication_key', 'bibtex', 'aux'])

        if len(self.__class__._editor_dfs) > 0:
            self.__class__.editor_df = pd.concat(self.__class__._editor_dfs, axis='index', ignore_index=True)
        else:
            self.__class__.editor_df = pd.DataFrame(columns=['person_id', 'publication_key'])

        return self.__class__.person_df, self.__class__.author_df, self.__class__.editor_df


def get_data_parsing_class(tag_name: str, attr_for_inner_text: T.Optional[str] = None):
    """
    Generates parsing class for any tag name, which handles all attributes in a generic way
    (integer or string, same attribute names in XML and in DB schema), adds publication_key.
    :param tag_name:
    :param attr_for_inner_text:
    :return:
    """

    class GeneratedDataParser(TagParser):
        _tqdm_prefix: str = f"{tag_name}_parser"
        _filtered_tags = {tag_name}
        _dfs = list()

        def _handle_filtered_tag(self, event, node: Element):
            tag_attrs = {k: v for k, v in node.attributes.items()}
            tag_attrs['publication_key'] = self.current_publication_key

            tag_content = get_node_text(node)
            if attr_for_inner_text is not None:
                tag_attrs[attr_for_inner_text] = tag_content

            for k, v in tag_attrs.items():
                if k in INT_MAPPING_TAGS:
                    tag_attrs[k] = int(v)
                elif tag_name == "ee" and k == "type":
                    # special handling for ee.type:
                    tag_attrs["is_archive"] = 'archive' in v
                    tag_attrs["is_oa"] = 'oa' in v
                    del tag_attrs[k]

            self.__class__._dfs.append(pd.DataFrame(tag_attrs, index=[1]))

        def _post_call(self):
            if len(self.__class__._dfs) > 0:
                self.__class__.df = pd.concat(self.__class__._dfs, axis='index', ignore_index=True)
            else:
                return None
            return self.__class__.df

    return GeneratedDataParser


class PublicationParser(TagParser):
    """ Parses Publication, School, Publisher and Series tables (from all related XML tags). """

    _tqdm_prefix: str = "publication_parser"
    _filtered_tags = {'school', 'publisher', 'series'}
    _publication_attr_tags = set(TAG_TO_ATTR_MAPPING.keys())

    _publication_dfs = list()
    dfs = {
        'school': pd.DataFrame(columns=['name']),
        'publisher': pd.DataFrame(columns=['name', 'href']),
        'series': pd.DataFrame(columns=['name', 'href']),
    }

    def __call__(self):
        for event, node in self.t:
            if event == pulldom.START_ELEMENT:
                if self.failed_flag is True:
                    continue

                if node.tagName in PUBLICATION_TAGNAMES:
                    if self.current_publication_key is not None:
                        raise ValueError(f"Overlapping top-level tags at key: {self.current_publication_key}")
                    self._handle_new_publication(node)
                else:
                    if self.current_publication_key is None:
                        log.warning(f"Omitting top-level tag: {node.tagName}")
                    elif node.tagName in self.__class__._filtered_tags:
                        self.doc.expandNode(node)
                        self._handle_filtered_tag(event, node)
                    elif node.tagName in self.__class__._publication_attr_tags:
                        self.doc.expandNode(node)
                        self._handle_publication_attr_tag(event, node)
                    else:
                        continue

            elif event == pulldom.END_ELEMENT and node.tagName in PUBLICATION_TAGNAMES:
                self._conclude_publication()
                # TODO: Remove this after finished debugging
                if self.n_parsed_publications > 10 ** 4:
                    break

        if self.pbar:
            self.t.close()
        return self._post_call()

    def _handle_new_publication(self, node):
        self.current_publication_attrs = dict()
        self.current_publication_attrs["category"] = node.tagName
        for k, v in node.attributes.items():
            if k == 'key':
                self.current_publication_key = v
            elif k in ATTR_TO_ATTR_MAPPING:
                mapper = ATTR_TO_ATTR_MAPPING[k]
                mapped = mapper(v)
                self.current_publication_attrs.update(**mapped)
            else:
                self.current_publication_attrs[k] = v

        if self.current_publication_key is None:
            raise ValueError(f"Publication without a key: {node}")

    def _handle_filtered_tag(self, event, node: Element):
        tag_attrs = {k: v for k, v in node.attributes.items()}
        tag_content = get_node_text(node)
        tag_attrs['name'] = tag_content

        # noinspection PyTypeChecker
        same_name: pd.Series = self.__class__.dfs[node.tagName]['name'] == tag_attrs['name']
        if same_name.any():
            # publisher, school and series are all compare by name
            relation_id = same_name.idxmax()
        else:
            relation_id = len(self.__class__.dfs[node.tagName])
            self.__class__.dfs[node.tagName] = self.__class__.dfs[node.tagName].append(
                tag_attrs, ignore_index=True
            )
        self.current_publication_attrs[f'{node.tagName}_id'] = relation_id

    def _handle_publication_attr_tag(self, event, node):
        tag_content = get_node_text(node)
        mapper = TAG_TO_ATTR_MAPPING[node.tagName]
        mapped = mapper(tag_content)
        self.current_publication_attrs.update(**mapped)

    def _conclude_publication(self):
        if not self.failed_flag:
            self.current_publication_attrs['key'] = self.current_publication_key
            self._publication_dfs.append(
                pd.DataFrame(self.current_publication_attrs, index=[1])
            )
        super(PublicationParser, self)._conclude_publication()

    def _post_call(self):
        self.__class__.publications_df = pd.concat(
            self.__class__._publication_dfs, axis='index', ignore_index=True
        )
        return (
            self.__class__.publications_df,
            self.__class__.dfs['school'],
            self.__class__.dfs['series'],
            self.__class__.dfs['publisher'],
        )


def save_df(df: pd.DataFrame, file_name: str, **kwargs):
    start_time = time.time()
    # escape char same as quote char, as specified in postgres documentation
    df.to_csv(file_name, quoting=csv.QUOTE_NONNUMERIC, escapechar='"', **kwargs)
    end_time = time.time()
    log.info(f"{file_name} saved in {end_time - start_time:.2f}s")


n_processes = min(len(GENERIC_DATA), cpu_count())
expected_event_count = 248393285  # for progressbar


def parse_generic_item(generic_data_tuple_with_filename) -> str:
    start = time.time()

    tagname, attrname, tablename, filename = generic_data_tuple_with_filename
    parser_builder = get_data_parsing_class(tagname, attrname)
    parser = parser_builder(filename, use_pbar=False)
    df = parser()
    if df is not None:
        save_df(df, f"{tablename}.csv", index=True, index_label='id')

    log.info("Clearing memory...")
    del df
    del parser
    del parser_builder
    gc.collect()
    log.info("Memory clear")

    end = time.time()
    return f"{tablename} finished in {end - start:.2}s"


def load_dblp(target: str, filename: str) -> None:
    assert target in {'publications', 'people', 'generic'}

    if not gc.isenabled():
        gc.enable()
    os.chdir(os.path.dirname(filename))  # so that relative reference to dtd file can be read by XML parser
    start = time.time()

    if target == 'publications':
        publiation_parser = PublicationParser(filename)
        publication_df, school_df, series_df, publisher_df = publiation_parser()
        save_df(publication_df, 'publication.csv', index=False)
        save_df(school_df, 'school.csv', index=True, index_label='id')
        save_df(series_df, 'series.csv', index=True, index_label='id')
        save_df(publisher_df, 'publisher.csv', index=True, index_label='id')

    elif target == 'people':
        person_parser = PersonTagParser(filename)
        person_df, author_df, editor_df = person_parser()
        save_df(person_df, 'person.csv', index=True, index_label='id')
        save_df(author_df, 'author.csv', index=False)
        save_df(editor_df, 'editor.csv', index=False)

    else:
        generic_data_tuples_with_filenames_and_offset = [
            (tagname, attrname, tablename, filename)
            for tagname, attrname, tablename in GENERIC_DATA
        ]
        with Pool(n_processes) as p:
            res = p.map_async(parse_generic_item, generic_data_tuples_with_filenames_and_offset)
            times = res.get()
            for t in times:
                log.info(t)

    end = time.time()
    log.info(f"Completed job {target} in {end-start:.2f}")
    gc.collect()


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    if len(sys.argv) < 1:
        log.error(f"Usage: {sys.argv[0]} [target] [filename]")
        exit(2)
    else:
        target = sys.argv[1]

    if len(sys.argv) > 2:
        filename = sys.argv[2]
    else:
        filename = "../data/dblp.xml"
        log.warning(f"Using default filename: {filename}")

    # noinspection PyUnboundLocalVariable
    load_dblp(target, filename)
