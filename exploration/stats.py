"""
Parse provided XML and calculate counts of top-level keys specified in
DTD (data model definition).
To prevent XML parser from throwing errors, need to replace all custom XML entities
before running the script.
"""

from xml.etree.cElementTree import iterparse, XMLParser

import click
from tqdm import tqdm


toplevel_keys = {
    'article',
    'inproceedings',
    'proceedings',
    'book',
    'incollection',
    'phdthesis',
    'mastersthesis',
    'www',
}


@click.command()
@click.argument("path", type=str)
@click.option("-e", "--expected-lines", type=int, default=124340518)
def parse_file(path: str, expected_lines: int) -> dict:
    actual_n_toplevel_elements = 0
    frequency_per_top_key = {k: {'freq': 0, 'keys_freq': dict()} for k in
                             toplevel_keys}  # top_key: (frequency, { sub_key: frequency })

    with open(path, 'r') as f:
        context = iterparse(f, events=("start", "end"))
        context = iter(context)

        event, root = next(context)
        assert event == "start"

        current_top_key = None
        root_tag = root.tag
        current_parent_key = root_tag  # TODO: Actually use a stack?
        for event, element in tqdm(context, total=expected_lines):
            if event == "start":
                current_parent_key = element.tag

                if element.tag in toplevel_keys:
                    current_top_key = element.tag
                    actual_n_toplevel_elements += 1
                    frequency_per_top_key[current_top_key]['freq'] += 1

                elif current_parent_key == root_tag:
                    raise Exception(
                        f"Invalid toplevel key at: parent_key={current_parent_key}, after_n_toplevel_elements={n_toplevel_elements}"
                    )

            else:  # end
                if element.tag == current_top_key:
                    for subelement in element:
                        try:
                            frequency_per_top_key[current_top_key]['keys_freq'][subelement.tag] += 1
                        except KeyError:
                            frequency_per_top_key[current_top_key]['keys_freq'][subelement.tag] = 1
                    current_top_key = root.tag
                    root.clear()

                elif element.tag == root_tag:
                    root.clear()
                    break

    print(f"Parsing stats: expected_lines={expected_lines}, actual_toplevel_elements={actual_n_toplevel_elements}")
    for key in toplevel_keys:
        print(f"{key}: {frequency_per_top_key[key]['freq']} ==> {frequency_per_top_key[key]['keys_freq']}")

    # TODO: More detailed stats


if __name__ == "__main__":
    parse_file()
