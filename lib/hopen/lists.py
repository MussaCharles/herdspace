"""Read a project list of hopen: a VS Code workspace file or a herdspace.toml file.

lib/hopen/lists.sh runs this file in read_list, with python3 -I:

    python3 -I lists.py FILE WHAT TEMPLATE

It prints one line for each workspace, tab, task, environment file, and
warning. The comment of read_list in lists.sh explains the format of the
lines. It uses only the standard library. A VS Code workspace file works with
any Python 3. A herdspace.toml file needs Python 3.11 or later, for tomllib.
"""
import json, os, re, sys, unicodedata

path, what, forced = sys.argv[1:4]
path = os.path.abspath(path)
base = os.path.dirname(path)


# Unicode categories that a list must not show or pass on: control characters
# (for example ESC), format characters (for example bidi marks that reorder
# text), and line or paragraph separators.
HIDDEN = ("Cc", "Cf", "Zl", "Zp", "Cs", "Co")

def has_hidden(value):
    return any(unicodedata.category(c) in HIDDEN for c in str(value))

def clean(value):
    # Tabs and new lines become spaces. Every other hidden character becomes
    # "?", so that a list cannot add a line or change what the approval
    # question shows.
    text = str(value).replace("\t", " ").replace("\n", " ").replace("\r", " ")
    return "".join("?" if unicodedata.category(c) in HIDDEN else c for c in text).strip()

def emit(kind, *fields, env=None):
    # Each output line goes through here, so each field is clean, and an
    # empty field is "-". The environment values are a list of clean
    # KEY=VALUE items.
    parts = [kind] + [clean(value) or "-" for value in fields]
    if env is not None:
        parts.append("\x1f".join(env) if env else "-")
    print("\x1e".join(parts))

def warn(text):
    emit("W", text)

if has_hidden(base):
    sys.exit("The folder of the list has a control character in its name.")

TEMPLATE_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*")

def template_name(value, where):
    # A template is a file in the templates folder of the person. A name with
    # "/" or ".." could point at a file from somewhere else, so it is refused.
    if value is None or value == "":
        return None
    if not isinstance(value, str) or not TEMPLATE_NAME.fullmatch(value):
        warn(f"{where}: the template name {clean(value)} is not valid. hopen uses the default.")
        return None
    return value

def field(value):
    return clean(value) or "-"

def list_path(raw):
    # A path with a hidden character could break the output lines.
    if has_hidden(raw):
        return None
    return os.path.normpath(os.path.join(base, os.path.expanduser(str(raw))))

if os.path.basename(path) == "herdspace.toml":
    if sys.version_info < (3, 11):
        how = "brew install python" if sys.platform == "darwin" else "sudo apt-get install python3.11, or with no sudo, uv python install 3.12"
        sys.exit("herdspace.toml needs Python 3.11 or later. Install one, for example with: " + how + ". A VS Code workspace file works with an older Python.")
    import tomllib
    with open(path, "rb") as handle:
        try:
            data = tomllib.load(handle)
        except tomllib.TOMLDecodeError as error:
            sys.exit(f"{path}: {error}")
    session = data.get("session") or os.path.basename(base)
    default = data.get("template", "plain")
    parent = data.get("parent_workspace", True)
    projects = []
    for entry in data.get("project", []):
        if not isinstance(entry, dict) or "path" not in entry:
            warn("A [[project]] entry has no path, so hopen skips it.")
            continue
        projects.append({
            "path": entry["path"],
            "name": entry.get("name"),
            "template": entry.get("template"),
            "on_open": entry.get("on_open", ""),
            "tabs": entry.get("tabs", []),
            "env": entry.get("env", {}),
            "env_file": entry.get("env_file"),
            "tasks": entry.get("tasks", {}),
        })
    parent_open = data.get("on_open", "")
    parent_tasks = data.get("tasks", {})
    parent_env = data.get("env", {})
    parent_env_file = data.get("env_file")
    parent_template = data.get("parent_template")
else:
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    # VS Code accepts comment lines and trailing commas.
    text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
    text = re.sub(r",(\s*[\]}])", r"\1", text)
    try:
        data = json.loads(text)
    except ValueError as error:
        sys.exit(f"{path}: {error}")
    settings = data.get("settings", {}) or {}
    session = settings.get("hopen.session") or os.path.basename(path)[: -len(".code-workspace")]
    default = settings.get("hopen.template", "plain")
    parent = settings.get("hopen.parentWorkspace", True)
    per_template = settings.get("hopen.templates", {}) or {}
    per_open = settings.get("hopen.onOpen", {}) or {}
    per_tabs = settings.get("hopen.tabs", {}) or {}
    per_env = settings.get("hopen.env", {}) or {}
    per_env_file = settings.get("hopen.envFile", {}) or {}
    per_tasks = settings.get("hopen.tasks", {}) or {}
    projects = []
    for folder in data.get("folders", []):
        if not isinstance(folder, dict) or "path" not in folder:
            warn("A folder entry has no path, so hopen skips it.")
            continue
        full = os.path.normpath(os.path.join(base, os.path.expanduser(folder["path"])))
        label = folder.get("name") or os.path.basename(full)
        projects.append({
            "path": folder["path"],
            "name": label,
            "template": per_template.get(label),
            "on_open": per_open.get(label, ""),
            "tabs": per_tabs.get(label, []),
            "env": per_env.get(label, {}),
            "env_file": per_env_file.get(label),
            "tasks": per_tasks.get(label, {}),
        })
    parent_tasks = per_tasks.get(session, {})
    parent_open = per_open.get(session, "")
    parent_env = per_env.get(session, {})
    parent_env_file = per_env_file.get(session)
    parent_template = per_template.get(session)

if not isinstance(parent, bool):
    warn("The parent workspace setting must be true or false. hopen uses true.")
    parent = True

if what == "session":
    if not clean(session):
        sys.exit("The session name of the list is empty.")
    print(clean(session))
    sys.exit(0)

default = template_name(default, "template") or "plain"

def template(value, where=""):
    return forced or template_name(value, where or "template") or default

def env_items(label, values):
    if not values:
        return []
    if not isinstance(values, dict):
        warn(f"{label}: env must be a map of names to values. hopen skips it.")
        return []
    items = []
    for key, value in values.items():
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", str(key)) or isinstance(value, (dict, list)):
            warn(f"{label}: the environment value {key} is not valid. hopen skips it.")
            continue
        if isinstance(value, bool):
            value = "true" if value else "false"
        items.append(f"{key}={clean(value)}")
    return items

ENV_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")

# An env file cannot set a name that makes a shell or a program run code.
# The approval question shows each other value, but it hides a value whose
# name looks like a secret.
RISKY = re.compile(r"PATH|HOME|SHELL|ENV|BASH_ENV|ZDOTDIR|PROMPT_COMMAND|PS[0-4]|IFS|TERM|TMPDIR"
                   r"|LD_.*|DYLD_.*|NODE_.*|NPM_CONFIG_.*|PYTHON.*|PERL.*|RUBY.*|GEM_.*|JAVA_.*|_JAVA_.*"
                   r"|GIT_.*|SSH_.*|XDG_.*|LESS.*|.*_COMMAND|.*_OPTIONS|.*_OPTS|.*PAGER|.*ASKPASS|.*EDITOR"
                   r"|VISUAL|BROWSER|HERDR_.*|HOPEN_.*", re.I)
SECRET = re.compile(r".*(TOKEN|SECRET|PASSWORD|PASSWD|PASS|PWD|KEY|CREDENTIAL|AUTH|PRIVATE|SESSION|COOKIE|DSN).*", re.I)

def env_file(label, raw, folder):
    # env_file reads a .env file: KEY=VALUE lines, with "#" comments, an
    # optional "export ", and optional quotes. A relative path starts at the
    # folder of the project. It emits one F line before the R or P line.
    if raw is None or raw == "":
        return
    if not isinstance(raw, str) or has_hidden(raw):
        warn(f"{label}: env_file must be a path. hopen skips it.")
        return
    file = os.path.normpath(os.path.join(folder, os.path.expanduser(raw)))
    try:
        with open(file, encoding="utf-8") as handle:
            lines = handle.read().split("\n")
    except (OSError, UnicodeDecodeError):
        warn(f"{label}: hopen cannot read the env file {clean(file)}. hopen skips it.")
        return
    items, names = [], []
    for number, line in enumerate(lines, 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export "):].lstrip()
        key, sep, value = line.partition("=")
        key, value = key.strip(), value.strip()
        if not sep or not ENV_NAME.fullmatch(key):
            warn(f"{label}: line {number} of {clean(file)} is not KEY=VALUE. hopen skips it.")
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        elif " #" in value:
            value = value.split(" #", 1)[0].rstrip()
        if RISKY.fullmatch(key):
            warn(f"{label}: an env file cannot set {key}, because it can run code. Put it in env, where the approval question shows it.")
            continue
        items.append(f"{key}={clean(value)}")
        names.append(f"{key}=(hidden)" if SECRET.fullmatch(key) else f"{key}={clean(value)}")
    if items:
        emit("F", label, file, ", ".join(names), env=items)

TASK_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.:-]*")

def tasks(label, values):
    # A task is a name and a command, like a task of tasks.json in VS Code.
    if not values:
        return
    if not isinstance(values, dict):
        warn(f"{label}: tasks must be a map of names to commands. hopen skips them.")
        return
    for name, command in values.items():
        if not TASK_NAME.fullmatch(str(name)) or not isinstance(command, str) or not clean(command):
            warn(f"{label}: the task {clean(name)} is not valid. A task is a name of letters, numbers, and . _ : -, and a command.")
            continue
        emit("K", label, name, command)

if parent:
    if not clean(session):
        sys.exit("The session name of the list is empty.")
    env_file(clean(session), parent_env_file, base)
    emit("R", session, base, template(parent_template, clean(session)), field(parent_open), env=env_items(clean(session), parent_env))
    tasks(clean(session), parent_tasks)
for project in projects:
    full = list_path(project["path"])
    if full is None:
        warn(f"A project path has a control character, so hopen skips it: {project['path']}")
        continue
    label = clean(project["name"] or os.path.basename(full))
    if not label or label == "-":
        warn(f"A project has an empty name, so hopen skips it: {project['path']}")
        continue
    env_file(label, project["env_file"], full)
    emit("P", label, full, template(project["template"], label), field(project["on_open"]), env=env_items(label, project["env"]))
    tasks(label, project["tasks"])
    tabs = project["tabs"]
    if not isinstance(tabs, list):
        warn(f"{label}: tabs must be a list. hopen skips them.")
        continue
    for tab in tabs:
        if not isinstance(tab, dict) or clean(tab.get("name") or "") in ("", "-"):
            warn(f"{label}: each tab needs a name. hopen skips one tab.")
            continue
        emit("T", label, tab["name"], template_name(tab.get("template"), f"{label}, tab {clean(tab['name'])}") or "plain", field(tab.get("run", "")))
