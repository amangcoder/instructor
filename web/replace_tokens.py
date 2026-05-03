import os

replacements = [
    ('bg-surface-container-high', 'bg-slate-800'),
    ('bg-surface-container', 'bg-slate-800/50'),
    ('hover:bg-surface-variant/20', 'hover:bg-white/5'),
    ('hover:bg-surface-variant/30', 'hover:bg-white/5'),
    ('bg-surface-variant/30', 'bg-slate-800/50'),
    ('bg-surface-variant', 'bg-slate-700'),
    ('text-on-surface-variant', 'text-slate-400'),
    ('text-on-surface', 'text-white'),
    ('border-outline-variant/50', 'border-white/5'),
    ('border-outline-variant', 'border-white/8'),
    ('bg-error-container', 'bg-red-950/80'),
    ('text-on-error-container', 'text-red-400'),
    ('text-on-primary', 'text-white'),
    ('bg-success-container', 'bg-emerald-950/80'),
    ('bg-warning-container', 'bg-amber-950/80'),
    ('hover:border-primary/30', 'hover:border-indigo-500/30'),
    ('hover:bg-primary/5', 'hover:bg-white/5'),
    ('hover:bg-primary/10', 'hover:bg-indigo-600/15'),
    ('hover:bg-primary/20', 'hover:bg-indigo-600/20'),
    ('hover:bg-primary/90', 'hover:bg-indigo-500'),
    ('hover:bg-error/90', 'hover:bg-red-500'),
    ('hover:bg-error/20', 'hover:bg-red-600/20'),
    ('hover:bg-error/10', 'hover:bg-red-600/10'),
    ('active:bg-primary/80', 'active:bg-indigo-700'),
    ('focus-visible:ring-primary', 'focus-visible:ring-indigo-400'),
    ('focus-within:ring-primary', 'focus-within:ring-indigo-400'),
    ('focus:ring-primary', 'focus:ring-indigo-400'),
    ('focus-visible:ring-error', 'focus-visible:ring-red-400'),
    ('bg-primary/50', 'bg-indigo-600/50'),
    ('bg-primary/15', 'bg-indigo-600/15'),
    ('bg-primary/10', 'bg-indigo-600/15'),
    ('bg-primary/5', 'bg-indigo-600/10'),
    ('bg-primary', 'bg-indigo-600'),
    ('text-primary', 'text-indigo-400'),
    ('text-error', 'text-red-400'),
    ('text-success', 'text-emerald-400'),
    ('text-warning', 'text-amber-400'),
    ('bg-error', 'bg-red-600'),
    ('bg-surface', 'bg-slate-900'),
    ('accent-primary', 'accent-indigo-600'),
    ('text-outline', 'text-slate-500'),
    ('border-primary', 'border-indigo-400'),
]

base = '/Users/amangupta/Projects/instructor/web'
exclude_dirs = {'__tests__', 'node_modules', '.next', '.swc'}

count = 0
for d in ['src/components', 'app']:
    for root, subdirs, files in os.walk(os.path.join(base, d)):
        subdirs[:] = [s for s in subdirs if s not in exclude_dirs]
        for fname in files:
            if not fname.endswith('.tsx'):
                continue
            fpath = os.path.join(root, fname)
            with open(fpath, 'r') as f:
                content = f.read()
            original = content
            for old, new in replacements:
                content = content.replace(old, new)
            if content != original:
                with open(fpath, 'w') as f:
                    f.write(content)
                count += 1
                print('Updated: ' + os.path.relpath(fpath, base))

print('Total files updated: ' + str(count))
