local builtins = {}

function builtins.to_string(scope)
  scope:add_include('<string>')
  scope:add_include('<sstream>')
  scope:add[[
const std::string& to_string(const std::string& str) {
  return str;
}

template<typename T>
std::string to_string(const T& in) {
  std::stringstream ss;
  ss << in;
  return ss.str();
}
]]
end

return builtins