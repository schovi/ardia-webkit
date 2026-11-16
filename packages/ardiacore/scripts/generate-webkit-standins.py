from pathlib import Path
import re

root = Path(__file__).resolve().parents[1] / 'ios'
headers = ['ArdiaHost', 'ArdiaWebView', 'ArdiaTabStrip', 'ArdiaEngineBridge', 'ArdiaServices', 'ArdiaContentBlocker', 'ArdiaFavicons', 'ArdiaSwipe', 'ArdiaChromeWindowHost']

def clean(text):
    return re.sub(r'\b(?:nullable|nonnull|_Nullable|_Nonnull)\b', '', text).strip()

def parameters(text):
    parts, start, depth = [], 0, 0
    for index, char in enumerate(text):
        depth += char in '(<'
        depth -= char in ')>'
        if char == ',' and depth == 0:
            parts.append(text[start:index].strip())
            start = index + 1
    parts.append(text[start:].strip())
    return [] if parts == ['void'] else parts

def method(signature):
    signature = re.sub(r'NS_SWIFT_NAME\([^;]*\)', '', signature).strip().rstrip(';').strip()
    result = re.match(r'[+-]\s*\(([^)]+)\)', signature)[1]
    body = ['static dispatch_once_t once;', 'dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); });']
    for block in re.finditer(r':\(void\s*\(\^\)\((.*?)\)\)\s*(\w+)', signature):
        arguments = ', '.join('{}' for _ in parameters(block[1]))
        body.append(f'if ({block[2]}) {block[2]}({arguments});')
    for block in re.finditer(r'\((ArdiaCoreResult|ArdiaServiceReply)\)\s*(\w+)', signature):
        arguments = '{}' if block[1] == 'ArdiaCoreResult' else '{}, {}'
        body.append(f'if ({block[2]}) {block[2]}({arguments});')
    if clean(result) != 'void':
        body.append('return {};')
    return signature + ' {\n  ' + '\n  '.join(body) + '\n}\n'

output = ['#import "../' + header + '.h"' for header in headers]
for header in headers:
    text = (root / (header + '.h')).read_text()
    for interface in re.finditer(r'@interface\s+(\w+)(?:\s*\((\w+)\)|\s*:[^\n]+)?(.*?)@end', text, re.S):
        name, category, contents = interface.groups()
        if name == 'ArdiaHost' and category == 'Launch':
            continue
        output.append('\n@implementation ' + name + (f' ({category})' if category else ''))
        for declaration in re.finditer(r'^[+-]\s*\(.*?;|@property\s*\(.*?;', contents, re.M | re.S):
            declaration = declaration[0]
            if declaration.startswith('@property'):
                attributes, value = re.match(r'@property\s*\((.*?)\)\s*(.*);', declaration, re.S).groups()
                kind = '+' if 'class' in attributes else '-'
                if '^' in value:
                    match = re.match(r'(.*?)\(\^(\w+)\)(.*)', value)
                    before, property_name, after = match.groups()
                    value_type = before + '(^)' + after
                else:
                    value_type, property_name = re.match(r'(.*?)\b(\w+)$', value.strip()).groups()
                getter = re.search(r'getter\s*=\s*(\w+)', attributes)
                if name != 'ArdiaHost' or property_name != 'dataDirectory':
                    output.append(method(f'{kind} ({value_type}){getter[1] if getter else property_name};'))
                if 'readonly' not in attributes:
                    output.append(method(f'{kind} (void)set{property_name[0].upper() + property_name[1:]}:({value_type})value;'))
            else:
                output.append(method(declaration))
        output.append('@end')
(root / 'webkit/Standins.mm').write_text('\n'.join(output) + '\n')
assert 'completion({});' in method('+ (void)test:(void (^)(BOOL ok))completion;')
assert 'completion({}, {});' in method('+ (void)test:(void (^)(id value, NSString *error))completion;')
