local builtins = {}

function builtins.to_string(scope)
  scope:add_include('<string>')
  scope:add_include('<sstream>')
  scope:add[[
inline const std::string& to_string(const std::string& s) { return s; }

template<typename T>
inline std::string to_string(const T& v) {
  std::stringstream ss;
  ss << v;
  return ss.str();
}
]]
end

return builtins