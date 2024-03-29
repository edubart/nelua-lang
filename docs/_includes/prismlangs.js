/* lua */
Prism.languages.lua = {
    'comment': /^#!.+|--(?:\[(=*)\[[\s\S]*?\]\1\]|.*)/m,
    // \z may be used to skip the following space
    'special': /\bself\b/,
    'builtin': /\b(?:false|true|nil)\b/,
    'keyword': /\b(?:and|break|do|else|elseif|end|for|function|goto|if|in|local|not|or|repeat|return|then|until|while)\b/,
    'function': /(?!\d)\w+(?=\s*(?:[({'"]))/,
    'string': {
        pattern: /(["'])(?:(?!\1)[^\\\r\n]|\\z(?:\r\n|\s)|\\(?:\r\n|[\s\S]))*\1|\[(=*)\[[\s\S]*?\]\2\]/,
        greedy: true
    },
    'number': /\b0x[a-f\d]+\.?[a-f\d]*(?:p[+-]?\d+)?\b|\b\d+(?:\.\B|\.?\d*(?:e[+-]?\d+)?\b)|\B\.\d+(?:e[+-]?\d+)?\b/i,
    'operator': [
        /[-+*%^&|#]|\/\/?|<[<=]?|>[>=]?|[=~]=?/,
        {
            // Match ".." but don't break "..."
            pattern: /(^|[^.])\.\.(?!\.)/,
            lookbehind: true
        }
    ],
    'punctuation': /[\[\](){},;]|\.+|:+/
};

/* nelua */
Prism.languages.nelua = {
    'preprocessor': [{
        pattern: /##\[(=*)\[[\s\S]*?\]\1\]/m,
        inside: {
            'macro': /##\[=*\[/,
            'rest': Prism.languages.lua,
            'macro_end': {
                pattern: /\]=*\]/,
                alias: 'macro'
            }
        }
    },{
        pattern: /##.*/,
        inside: {
            'macro': /##/,
            'rest': Prism.languages.lua
        }
    }, {
        pattern: /#\|[\s\S]*?\|#/m,
        lookbehind: true,
        inside: {
            'macro': /#\||\|#/,
            'rest': Prism.languages.lua
        }
    },{
        pattern: /#\[[\s\S]*?\]#/m,
        lookbehind: true,
        inside: {
            'macro': /#\[|\]#/,
            'rest': Prism.languages.lua
        }
    }],
    'comment': /^#!.+|--(?:\[(=*)\[[\s\S]*?\]\1\]|.*)/m,
    'special': /\bself\b/,
    'builtin': /\b(?:false|true|nil|nilptr)\b/,
    'keyword': /\b(?:and|break|do|else|elseif|end|for|function|goto|if|in|local|not|or|repeat|return|then|until|while|switch|case|continue|fallthrough|global|defer)\b/,
    'type': [{
        pattern: /(@)\w+/,
        lookbehind: true
    }, {
        pattern: /(\:)\s+\w+/,
        lookbehind: true
    }],
    'function': /(?!\d)\w+(?=\s*(?:[({'"]))/,
    'annotation': {
        pattern: /\<[\w]+\s*(,\s*[\w]+\s*)*\>/,
        inside: Prism.languages.lua
    },
    'string': {
        pattern: /(["'])(?:(?!\1)[^\\\r\n]|\\z(?:\r\n|\s)|\\(?:\r\n|[\s\S]))*\1|\[(=*)\[[\s\S]*?\]\2\]/,
        greedy: true
    },
    'number': /\b0x[a-f\d]+\.?[a-f\d]*(?:p[+-]?\d+)?(_\w+)?\b|\b\d+(?:\.\B|\.?\d*(?:e[+-]?\d+)?(_\w+)?\b)|\B\.\d+(?:e[+-]?\d+)?(_\w+)?\b/i,
    'operator': [
        /[-@$+*%^&|#?]|\/\/?|<[<=]?|>[>=]?|[=~]=?/,
        {
            // Match ".." but don't break "..."
            pattern: /(^|[^.])\.\.(?!\.)/,
            lookbehind: true
        }
    ],
    'punctuation': /[\[\](){},;]|\.+|:+/
};

/* C */
Prism.languages.clike = {
    'comment': [
        {
            pattern: /(^|[^\\])\/\*[\s\S]*?(?:\*\/|$)/,
            lookbehind: true
        },
        {
            pattern: /(^|[^\\:])\/\/.*/,
            lookbehind: true,
            greedy: true
        }
    ],
    'string': {
        pattern: /(["'])(?:\\(?:\r\n|[\s\S])|(?!\1)[^\\\r\n])*\1/,
        greedy: true
    },
    'class-name': {
        pattern: /(\b(?:class|interface|extends|implements|trait|instanceof|new)\s+|\bcatch\s+\()[\w.\\]+/i,
        lookbehind: true,
        inside: {
            'punctuation': /[.\\]/
        }
    },
    'keyword': /\b(?:if|else|while|do|for|return|in|instanceof|function|new|try|throw|catch|finally|null|break|continue)\b/,
    'boolean': /\b(?:true|false)\b/,
    'function': /\w+(?=\()/,
    'number': /\b0x[\da-f]+\b|(?:\b\d+\.?\d*|\B\.\d+)(?:e[+-]?\d+)?/i,
    'operator': /[<>]=?|[!=]=?=?|--?|\+\+?|&&?|\|\|?|[?*/~^%]/,
    'punctuation': /[{}[\];(),.:]/
};

Prism.languages.c = Prism.languages.extend('clike', {
    'comment': {
        pattern: /\/\/(?:[^\r\n\\]|\\(?:\r\n?|\n|(?![\r\n])))*|\/\*[\s\S]*?(?:\*\/|$)/,
        greedy: true
    },
    'class-name': {
        pattern: /(\b(?:enum|struct)\s+(?:__attribute__\s*\(\([\s\S]*?\)\)\s*)?)\w+/,
        lookbehind: true
    },
    'keyword': /\b(?:__attribute__|_Alignas|_Alignof|_Atomic|_Bool|_Complex|_Generic|_Imaginary|_Noreturn|_Static_assert|_Thread_local|asm|typeof|inline|auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|int|long|register|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while)\b/,
    'function': /[a-z_]\w*(?=\s*\()/i,
    'operator': />>=?|<<=?|->|([-+&|:])\1|[?:~]|[-+*/%&|^!=<>]=?/,
    'number': /(?:\b0x(?:[\da-f]+\.?[\da-f]*|\.[\da-f]+)(?:p[+-]?\d+)?|(?:\b\d+\.?\d*|\B\.\d+)(?:e[+-]?\d+)?)[ful]*/i
});

Prism.languages.insertBefore('c', 'string', {
    'macro': {
        // allow for multiline macro definitions
        // spaces after the # character compile fine with gcc
        pattern: /(^\s*)#\s*[a-z]+(?:[^\r\n\\/]|\/(?!\*)|\/\*(?:[^*]|\*(?!\/))*\*\/|\\(?:\r\n|[\s\S]))*/im,
        lookbehind: true,
        greedy: true,
        alias: 'property',
        inside: {
            'string': [
                {
                    // highlight the path of the include statement as a string
                    pattern: /^(#\s*include\s*)<[^>]+>/,
                    lookbehind: true
                },
                Prism.languages.c['string']
            ],
            'comment': Prism.languages.c['comment'],
            // highlight macro directives as keywords
            'directive': {
                pattern: /^(#\s*)[a-z]+/,
                lookbehind: true,
                alias: 'keyword'
            },
            'directive-hash': /^#/,
            'punctuation': /##|\\(?=[\r\n])/,
            'expression': {
                pattern: /\S[\s\S]*/,
                inside: Prism.languages.c
            }
        }
    },
    // highlight predefined macros as constants
    'constant': /\b(?:__FILE__|__LINE__|__DATE__|__TIME__|__TIMESTAMP__|__func__|EOF|NULL|SEEK_CUR|SEEK_END|SEEK_SET|stdin|stdout|stderr)\b/
});

delete Prism.languages.c['boolean'];

/* bash */
(function(Prism) {
// $ set | grep '^[A-Z][^[:space:]]*=' | cut -d= -f1 | tr '\n' '|'
// + LC_ALL, RANDOM, REPLY, SECONDS.
// + make sure PS1..4 are here as they are not always set,
// - some useless things.
var envVars = '\\b(?:BASH|BASHOPTS|BASH_ALIASES|BASH_ARGC|BASH_ARGV|BASH_CMDS|BASH_COMPLETION_COMPAT_DIR|BASH_LINENO|BASH_REMATCH|BASH_SOURCE|BASH_VERSINFO|BASH_VERSION|COLORTERM|COLUMNS|COMP_WORDBREAKS|DBUS_SESSION_BUS_ADDRESS|DEFAULTS_PATH|DESKTOP_SESSION|DIRSTACK|DISPLAY|EUID|GDMSESSION|GDM_LANG|GNOME_KEYRING_CONTROL|GNOME_KEYRING_PID|GPG_AGENT_INFO|GROUPS|HISTCONTROL|HISTFILE|HISTFILESIZE|HISTSIZE|HOME|HOSTNAME|HOSTTYPE|IFS|INSTANCE|JOB|LANG|LANGUAGE|LC_ADDRESS|LC_ALL|LC_IDENTIFICATION|LC_MEASUREMENT|LC_MONETARY|LC_NAME|LC_NUMERIC|LC_PAPER|LC_TELEPHONE|LC_TIME|LESSCLOSE|LESSOPEN|LINES|LOGNAME|LS_COLORS|MACHTYPE|MAILCHECK|MANDATORY_PATH|NO_AT_BRIDGE|OLDPWD|OPTERR|OPTIND|ORBIT_SOCKETDIR|OSTYPE|PAPERSIZE|PATH|PIPESTATUS|PPID|PS1|PS2|PS3|PS4|PWD|RANDOM|REPLY|SECONDS|SELINUX_INIT|SESSION|SESSIONTYPE|SESSION_MANAGER|SHELL|SHELLOPTS|SHLVL|SSH_AUTH_SOCK|TERM|UID|UPSTART_EVENTS|UPSTART_INSTANCE|UPSTART_JOB|UPSTART_SESSION|USER|WINDOWID|XAUTHORITY|XDG_CONFIG_DIRS|XDG_CURRENT_DESKTOP|XDG_DATA_DIRS|XDG_GREETER_DATA_DIR|XDG_MENU_PREFIX|XDG_RUNTIME_DIR|XDG_SEAT|XDG_SEAT_PATH|XDG_SESSION_DESKTOP|XDG_SESSION_ID|XDG_SESSION_PATH|XDG_SESSION_TYPE|XDG_VTNR|XMODIFIERS)\\b';
var insideString = {
    'environment': {
        pattern: RegExp("\\$" + envVars),
        alias: 'constant'
    },
    'variable': [
        // [0]: Arithmetic Environment
        {
            pattern: /\$?\(\([\s\S]+?\)\)/,
            greedy: true,
            inside: {
                // If there is a $ sign at the beginning highlight $(( and )) as variable
                'variable': [
                    {
                        pattern: /(^\$\(\([\s\S]+)\)\)/,
                        lookbehind: true
                    },
                    /^\$\(\(/
                ],
                'number': /\b0x[\dA-Fa-f]+\b|(?:\b\d+\.?\d*|\B\.\d+)(?:[Ee]-?\d+)?/,
                // Operators according to https://www.gnu.org/software/bash/manual/bashref.html#Shell-Arithmetic
                'operator': /--?|-=|\+\+?|\+=|!=?|~|\*\*?|\*=|\/=?|%=?|<<=?|>>=?|<=?|>=?|==?|&&?|&=|\^=?|\|\|?|\|=|\?|:/,
                // If there is no $ sign at the beginning highlight (( and )) as punctuation
                'punctuation': /\(\(?|\)\)?|,|;/
            }
        },
        // [1]: Command Substitution
        {
            pattern: /\$\((?:\([^)]+\)|[^()])+\)|`[^`]+`/,
            greedy: true,
            inside: {
                'variable': /^\$\(|^`|\)$|`$/
            }
        },
        // [2]: Brace expansion
        {
            pattern: /\$\{[^}]+\}/,
            greedy: true,
            inside: {
                'operator': /:[-=?+]?|[!\/]|##?|%%?|\^\^?|,,?/,
                'punctuation': /[\[\]]/,
                'environment': {
                    pattern: RegExp("(\\{)" + envVars),
                    lookbehind: true,
                    alias: 'constant'
                }
            }
        },
        /\$(?:\w+|[#?*!@$])/
    ],
    // Escape sequences from echo and printf's manuals, and escaped quotes.
    'entity': /\\(?:[abceEfnrtv\\"]|O?[0-7]{1,3}|x[0-9a-fA-F]{1,2}|u[0-9a-fA-F]{4}|U[0-9a-fA-F]{8})/
};

Prism.languages.bash = {
    'shebang': {
        pattern: /^#!\s*\/.*/,
        alias: 'important'
    },
    'comment': {
        pattern: /(^|[^"{\\$])#.*/,
        lookbehind: true
    },
    'function-name': [
        // a) function foo {
        // b) foo() {
        // c) function foo() {
        // but not “foo {”
        {
            // a) and c)
            pattern: /(\bfunction\s+)\w+(?=(?:\s*\(?:\s*\))?\s*\{)/,
            lookbehind: true,
            alias: 'function'
        },
        {
            // b)
            pattern: /\b\w+(?=\s*\(\s*\)\s*\{)/,
            alias: 'function'
        }
    ],
    // Highlight variable names as variables in for and select beginnings.
    'for-or-select': {
        pattern: /(\b(?:for|select)\s+)\w+(?=\s+in\s)/,
        alias: 'variable',
        lookbehind: true
    },
    // Highlight variable names as variables in the left-hand part
    // of assignments (“=” and “+=”).
    'assign-left': {
        pattern: /(^|[\s;|&]|[<>]\()\w+(?=\+?=)/,
        inside: {
            'environment': {
                pattern: RegExp("(^|[\\s;|&]|[<>]\\()" + envVars),
                lookbehind: true,
                alias: 'constant'
            }
        },
        alias: 'variable',
        lookbehind: true
    },
    'string': [
        // Support for Here-documents https://en.wikipedia.org/wiki/Here_document
        {
            pattern: /((?:^|[^<])<<-?\s*)(\w+?)\s*(?:\r?\n|\r)[\s\S]*?(?:\r?\n|\r)\2/,
            lookbehind: true,
            greedy: true,
            inside: insideString
        },
        // Here-document with quotes around the tag
        // → No expansion (so no “inside”).
        {
            pattern: /((?:^|[^<])<<-?\s*)(["'])(\w+)\2\s*(?:\r?\n|\r)[\s\S]*?(?:\r?\n|\r)\3/,
            lookbehind: true,
            greedy: true
        },
        // “Normal” string
        {
            pattern: /(^|[^\\](?:\\\\)*)(["'])(?:\\[\s\S]|\$\([^)]+\)|`[^`]+`|(?!\2)[^\\])*\2/,
            lookbehind: true,
            greedy: true,
            inside: insideString
        }
    ],
    'environment': {
        pattern: RegExp("\\$?" + envVars),
        alias: 'constant'
    },
    'variable': insideString.variable,
    'function': {
        pattern: /(^|[\s;|&]|[<>]\()(?:add|apropos|apt|aptitude|apt-cache|apt-get|aspell|automysqlbackup|awk|basename|bash|bc|bconsole|bg|bzip2|cal|cat|cfdisk|chgrp|chkconfig|chmod|chown|chroot|cksum|clear|cmp|column|comm|composer|cp|cron|crontab|csplit|curl|cut|date|dc|dd|ddrescue|debootstrap|df|diff|diff3|dig|dir|dircolors|dirname|dirs|dmesg|du|egrep|eject|env|ethtool|expand|expect|expr|fdformat|fdisk|fg|fgrep|file|find|fmt|fold|format|free|fsck|ftp|fuser|gawk|git|gparted|grep|groupadd|groupdel|groupmod|groups|grub-mkconfig|gzip|halt|head|hg|history|host|hostname|htop|iconv|id|ifconfig|ifdown|ifup|import|ip|jobs|join|kill|killall|less|link|ln|locate|logname|logrotate|look|lpc|lpr|lprint|lprintd|lprintq|lprm|ls|lsof|lynx|make|man|mc|mdadm|mkconfig|mkdir|mke2fs|mkfifo|mkfs|mkisofs|mknod|mkswap|mmv|more|most|mount|mtools|mtr|mutt|mv|nano|nc|netstat|nice|nl|nohup|notify-send|npm|nslookup|op|open|parted|passwd|paste|pathchk|ping|pkill|pnpm|popd|pr|printcap|printenv|ps|pushd|pv|quota|quotacheck|quotactl|ram|rar|rcp|reboot|remsync|rename|renice|rev|rm|rmdir|rpm|rsync|scp|screen|sdiff|sed|sendmail|seq|service|sftp|sh|shellcheck|shuf|shutdown|sleep|slocate|sort|split|ssh|stat|strace|su|sudo|sum|suspend|swapon|sync|tac|tail|tar|tee|time|timeout|top|touch|tr|traceroute|tsort|tty|umount|uname|unexpand|uniq|units|unrar|unshar|unzip|update-grub|uptime|useradd|userdel|usermod|users|uudecode|uuencode|v|vdir|vi|vim|virsh|vmstat|wait|watch|wc|wget|whereis|which|who|whoami|write|xargs|xdg-open|yarn|yes|zenity|zip|zsh|zypper)(?=$|[)\s;|&])/,
        lookbehind: true
    },
    'extra-functions': {
        pattern: /(^|[\s;|&]|[<>]\()(?:nelua|luarocks|pacman)(?=$|[)\s;|&])/,
        lookbehind: true,
        alias: 'function'
    },
    'keyword': {
        pattern: /(^|[\s;|&]|[<>]\()(?:if|then|else|elif|fi|for|while|in|case|esac|function|select|do|done|until)(?=$|[)\s;|&])/,
        lookbehind: true
    },
    // https://www.gnu.org/software/bash/manual/html_node/Shell-Builtin-Commands.html
    'builtin': {
        pattern: /(^|[\s;|&]|[<>]\()(?:\.|:|break|cd|continue|eval|exec|exit|export|getopts|hash|pwd|readonly|return|shift|test|times|trap|umask|unset|alias|bind|builtin|caller|command|declare|echo|enable|help|let|local|logout|mapfile|printf|read|readarray|source|type|typeset|ulimit|unalias|set|shopt)(?=$|[)\s;|&])/,
        lookbehind: true,
        // Alias added to make those easier to distinguish from strings.
        alias: 'class-name'
    },
    'boolean': {
        pattern: /(^|[\s;|&]|[<>]\()(?:true|false)(?=$|[)\s;|&])/,
        lookbehind: true
    },
    'file-descriptor': {
        pattern: /\B&\d\b/,
        alias: 'important'
    },
    'operator': {
        // Lots of redirections here, but not just that.
        pattern: /\d?<>|>\||\+=|==?|!=?|=~|<<[<-]?|[&\d]?>>|\d?[<>]&?|&[>&]?|\|[&|]?|<=?|>=?/,
        inside: {
            'file-descriptor': {
                pattern: /^\d/,
                alias: 'important'
            }
        }
    },
    'punctuation': /\$?\(\(?|\)\)?|\.\.|[{}[\];\\]/,
    'number': {
        pattern: /(^|\s)(?:[1-9]\d*|0)(?:[.,]\d+)?\b/,
        lookbehind: true
    }
};

/* Patterns in command substitution. */
var toBeCopied = [
    'comment',
    'function-name',
    'for-or-select',
    'assign-left',
    'string',
    'environment',
    'function',
    'keyword',
    'builtin',
    'boolean',
    'file-descriptor',
    'operator',
    'punctuation',
    'number'
];
var inside = insideString.variable[1].inside;
for(var i = 0; i < toBeCopied.length; i++) {
    inside[toBeCopied[i]] = Prism.languages.bash[toBeCopied[i]];
}

Prism.languages.shell = Prism.languages.bash;

})(Prism);
