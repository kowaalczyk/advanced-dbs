import typing as T
import logging

import os

from xml.dom import pulldom
from xml.sax import make_parser
from xml.sax.handler import feature_external_ges

from tqdm import tqdm


log = logging.getLogger(__name__)

parser = make_parser()
parser.setFeature(feature_external_ges, True)

note_types = set()
ee_types = set()
url_types = set()
isbn_types = set()


def analyze_document(filename: str = "../data/dblp.xml", expected_event_count: T.Optional[int] = 248393285):
    """
    New function for dblp xml analysis used to correct my database schema.
    :param filename:
    :param expected_event_count:
    :return:
    """
    os.chdir(os.path.dirname(filename))  # so that relative reference to dtd file can be read by XML parser
    doc = pulldom.parse(filename, parser=parser, bufsize=2 ** 14)

    for event, node in tqdm(doc, total=expected_event_count):
        if event == pulldom.START_ELEMENT:
            if node.tagName == "note":
                for k, v in node.attributes.items():
                    if k == 'type':
                        note_types.add(v)
            elif node.tagName == "ee":
                for k, v in node.attributes.items():
                    if k == 'type':
                        ee_types.add(v)
            elif node.tagName == "url":
                for k, v in node.attributes.items():
                    if k == 'type':
                        url_types.add(v)
            elif node.tagName == "isbn":
                for k, v in node.attributes.items():
                    if k == 'type':
                        isbn_types.add(v)
            # doc.expandNode(node)

    for s in [note_types, ee_types, url_types, isbn_types]:
        print(list(s))


if __name__ == "__main__":
    analyze_document()
