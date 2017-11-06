local builtins = {}

function builtins.to_string(scope)
  scope:add_include('<string>')
  scope:add_include('<sstream>')
  scope:add_include('<cstddef>')
  scope:add_include('<array>')
  scope:add_include('<type_traits>')
  scope:add[[
inline const std::string& to_string(const std::string& s) { return s; }
inline const std::string& to_string(const bool& b) {
  static std::string strue("true");
  static std::string sfalse("false");
  return b ? strue : sfalse;
}

inline const std::string& to_string(const std::nullptr_t&) {
  static std::string snil("nil");
  return snil;
}

template <class T, std::enable_if_t<std::is_scalar<T>::value, int> = 0>
inline std::string to_string(const T& v) {
  std::stringstream ss;
  ss << v;
  return ss.str();
}

template<typename T, unsigned long N>
inline std::string to_string(const std::array<T, N>& array) {
  std::stringstream ss;
  ss << "[";
  for(unsigned long i=0;i<array.size();++i) {
    if(i != 0)
      ss << ", ";
    ss << to_string(array[i]);
  }
  ss << "]";
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