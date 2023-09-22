import xml.etree.ElementTree as ET
import json


for filename in ["./allSprites_retina", "./allSprites_default"]:
    obj = {}
    tree = ET.parse(filename + ".xml");
    root = tree.getroot();
    with open(filename + ".json", "w") as f:
        for i, child in enumerate(root):
            entry = {}
            entry['name'] = child.attrib['name']
            entry['pos'] = {'x': int(child.attrib['x']), 'y': int(child.attrib['y'])}
            entry['width'] = int(child.attrib['width'])
            entry['height'] = int(child.attrib['height'])
            entry['origin'] = { 'x': entry['width']/2, 'y': entry['height']/2 }
            obj[entry['name']] = entry

        json.dump(obj, f, indent=2)


