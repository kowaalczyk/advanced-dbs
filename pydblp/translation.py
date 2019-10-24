import typing as T

from pydblp.models import Publisher, School, Series, Author, Editor, ElectronicEdition, CrossRef, Cite, Note, Url, ISBN


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

""" Dependencies to create Publication """
DEPS_TAGNAMES = {
    'publisher': Publisher,
    'school': School,
    'series': Series,
}

""" Dependencies requiring both Publication and Person """
SECONDARY_DEPS_TAGNAMES = {
    'author': Author,
    'editor': Editor,
}

""" Optional data related to a given Publication """
DATA_TAGNAMES = {
    'ee': ElectronicEdition.from_xml,
    'crossref': CrossRef,
    'cite': Cite,
    'note': Note,
    'url': Url,
    'isbn': ISBN,
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


TAG_TO_ATTR_MAPPING = {
    'pages': page_mapper,
    **{k: get_default_mapper(k) for k in DEFAULT_MAPPING_TAGS},
    **{k: get_int_mapper(k) for k in INT_MAPPING_TAGS}
}

ATTR_TO_ATTR_MAPPING = {
    'publtype': get_default_mapper('type__'),
    **{a: get_default_mapper(a) for a in {'cdate', 'mdate'}}
    # key is stored separately to easily pass to dependent models
}

TAG_CONTENT_TO_DATA_ATTR_MAPPING = {
    'publisher': 'name',
    'school': 'name',
    'series': 'name',
    'cite': 'str__',
    'crossref': 'str__',
    'ee': 'url',
    'isbn': 'isbn',
    'url': 'url',
    'note': 'note',
}

PUBLICATION_TYPES = {
    'habil',
    'withdrawn',
    'survey',
    'informal withdrawn',
    'noshow',
    'disambiguation',
    'data',
    'software',
    'encyclopedia',
    'edited',
    'group',
    'informal',
}
# note_types = {'source', 'rating', 'uname', 'reviewid', 'disstype', 'affiliation', 'doi', 'isnot', 'isbn', 'award'}
# ee_types = {'archive oa', 'archive', 'oa'}  # TODO: flags for archive and oa (!!!)
# url_types = {'archive', 'deprecated'}
# isbn_types = {'usb', 'print', 'online', 'electronic'}
