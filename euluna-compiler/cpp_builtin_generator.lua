local builtins = {}

function builtins.to_string(scope)
  scope:add_include('<string>')
  scope:add_include('<sstream>')
  scope:add[[
inline const std::string& to_string(const std::string& s) { return s; }
inline const std::string& to_string(const bool& b) {
  static std::string btrue("true");
  static std::string bfalse("false");
  return b ? btrue : bfalse;
}

inline std::string to_string(const auto& v) {
  std::stringstream ss;
  ss << v;
  return ss.str();
}
]]
end

function builtins.make_deferrer(scope)
  scope:add[[
template<class F>
struct deferrer {
    F f;
    ~deferrer() { f(); }
};
template<class F>
inline deferrer<F> make_deferrer(F&& f) { return {f}; }
]]
end

function builtins.iterator_items(scope)
  scope:add[[
inline void iterator_items(const auto& container, auto&& f) {
    for(auto v : container)
      f(v);
}
inline void iterator_mitems(auto& container, auto&& f) {
    for(auto& v : container)
      f(v);
}
]]
end

return builtins