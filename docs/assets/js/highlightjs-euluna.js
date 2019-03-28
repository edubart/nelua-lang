hljs.registerLanguage("euluna", function(e) {
  var OPENING_LONG_BRACKET = "\\[=*\\[",
      CLOSING_LONG_BRACKET = "\\]=*\\]",
      LONG_BRACKETS = {
        b: OPENING_LONG_BRACKET,
        e: CLOSING_LONG_BRACKET,
        c: ["self"]
      },
      COMMENTS = [
        e.C("--(?!" + OPENING_LONG_BRACKET + ")", "$"),
        e.C("--" + OPENING_LONG_BRACKET,
        CLOSING_LONG_BRACKET, {
            c: [LONG_BRACKETS],
            r: 10
          })
      ];
  return {
    l:e.UIR, k: {
      literal: "true false nil",
      keyword:
        //Lua
        "function and break do else elseif end for goto if in local not or repeat return then until while " +
        //Extended lua
        "switch case try except raise defer continue import " +
        "typedef export " +
        "struct enum " +
        "template concept " +
        "literal " +
        "var val const"
      ,
      built_in:
        //Metatags and globals:
        '_G _ENV _VERSION __index __newindex __mode __call __metatable __tostring __len ' +
        '__gc __add __sub __mul __div __mod __pow __concat __unm __eq __lt __le assert ' +
        //Standard methods and properties:
        'collectgarbage dofile error getfenv getmetatable ipairs load loadfile loadstring' +
        'module next pairs pcall print rawequal rawget rawset require select setfenv' +
        'setmetatable tonumber tostring type unpack xpcall arg self ' +
        //Library methods and properties (one line per library):
        'coroutine resume status wrap create running debug getupvalue ' +
        'debug sethook getmetatable gethook setmetatable setlocal traceback setfenv getinfo setupvalue getlocal getregistry getfenv ' +
        'io lines write close flush open output type read stderr stdin input stdout popen tmpfile ' +
        'math log max acos huge ldexp pi cos tanh pow deg tan cosh sinh random randomseed frexp ceil floor rad abs sqrt modf asin min mod fmod log10 atan2 exp sin atan ' +
        'os exit setlocale date getenv difftime remove time clock tmpname rename execute package preload loadlib loaded loaders cpath config path seeall ' +
        'string sub upper len gfind rep find match char dump gmatch reverse byte format gsub lower ' +
        'table setn insert getn foreachi maxn foreach concat sort remove ' +
        //Extended lua
        'char uchar int uint int16 uint16 int32 uint32 int64 uint64 ' +
        'isize usize float double ptr typed untyped ' +
        'void '
    },
    c:COMMENTS.concat([
      e.CNM,
      e.ASM,
      e.QSM,
      {
        cN: "string",
        b: OPENING_LONG_BRACKET,
        e: CLOSING_LONG_BRACKET,
        c: [LONG_BRACKETS],
        r: 5
      }
    ])
  }
}

);
