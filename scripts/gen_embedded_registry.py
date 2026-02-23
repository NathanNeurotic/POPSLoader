#!/usr/bin/env python3
from pathlib import Path
import sys

def mk_id(p):
    return '_' + p.replace('/','_').replace('.','_')

def sym_for(id_):
    blob = f"asm/embedded/tmp/{id_}.gz".replace('/','_').replace('.','_').replace('-','_')
    return f"_binary_{blob}"

def aliases(path):
    out={path}
    if path.startswith('bin/POPSLDR/'):
        rel=path[len('bin/POPSLDR/'):]
        out.add(rel)
        out.add('POPSLDR/'+rel)
    if path.startswith('etc/'):
        rel=path[len('etc/'):]
        out.add(rel)
    return sorted(out)

out=Path(sys.argv[1])
assets=[a for a in sys.argv[2:] if Path(a).is_file()]
lines=[]
lines.append('// generated; do not edit')
lines.append('struct EmbeddedEntryDef { const char* path; const unsigned char* start; unsigned int size; bool compressed; };')
externs=[]
rows=[]
for a in assets:
    id_=mk_id(a)
    sym=sym_for(id_)
    externs.append(f'extern const unsigned char {sym}_start[];')
    externs.append(f'extern const unsigned char {sym}_end[];')
    for al in aliases(a):
        rows.append((al,sym))
lines.extend(sorted(set(externs)))
lines.append('static const EmbeddedEntryDef kEmbeddedEntries[] = {')
for p,s in sorted(rows):
    lines.append(f'    {{"{p}", {s}_start, (unsigned int)({s}_end - {s}_start), true}},')
lines.append('};')
out.write_text('\n'.join(lines)+'\n')
