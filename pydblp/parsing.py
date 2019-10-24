import typing as T
from xml.dom.minidom import Element

from pydblp.models import Person
from pydblp.translation import DEPS_TAGNAMES, TAG_CONTENT_TO_DATA_ATTR_MAPPING, DATA_TAGNAMES


def get_node_text(node: Element) -> str:
    """
    Returns entire XML contained within a node (without beginning and opening tag) as a string.
    :param node:
    :return: node text
    """
    return node.toxml().replace(f"<{node.tagName}>", "").replace(f"</{node.tagName}>", "")


def parse_dependency(node: Element) -> str:
    """
    Parses a publication dependency into an appropriate model with all attributes
    :param node:
    :return: initialized dependency model
    """
    tag_class = DEPS_TAGNAMES[node.tagName]
    tag_attrs = {k: v for k, v in node.attributes.items()}
    if node.tagName in TAG_CONTENT_TO_DATA_ATTR_MAPPING.keys():
        tag_content_attr = TAG_CONTENT_TO_DATA_ATTR_MAPPING[node.tagName]
        tag_content = get_node_text(node)
        tag_attrs.update(**{tag_content_attr: tag_content})
    new_dep = tag_class(**tag_attrs)
    return new_dep


def parse_data(node: Element, current_key: str) -> str:
    """
    Parses a publication additional data into an appropriate model with all attributes
    :param node:
    :param current_key: key of current publication
    :return: initialized data model
    """
    tag_class = DATA_TAGNAMES[node.tagName]
    tag_attrs = {str(k).replace("type", "type__"): v for k, v in node.attributes.items()}
    if node.tagName in TAG_CONTENT_TO_DATA_ATTR_MAPPING.keys():
        tag_content_attr = TAG_CONTENT_TO_DATA_ATTR_MAPPING[node.tagName]
        tag_content = get_node_text(node)
        tag_attrs.update(**{tag_content_attr: tag_content})
    new_data = tag_class(publication_key=current_key, **tag_attrs)
    return new_data


def parse_secondary_dependency(node: Element, ) -> T.Tuple[Person, str, T.Dict[str, T.Any]]:
    """
    Parses a publication secondary dependency into a Person and dependency (Editor or Author) data model
    (the Person.id is still needed to be selected from DB to create the dependency data model)
    :param node:
    :return: Person, secondary dependency type ("editor" or "author"), secondary dependency attributes dict
    """
    dependency_name = node.tagName
    dependency_attrs = dict()
    person_attrs = dict()
    for k, v in node.attributes.items():
        if k in {'orcid'}:
            person_attrs[k] = v
        else:
            dependency_attrs[k] = v
    tag_content = get_node_text(node)
    person_attrs['full_name'] = tag_content
    person = Person(**person_attrs)
    return person, dependency_name, dependency_attrs
