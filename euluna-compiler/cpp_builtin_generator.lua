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

function builtins.as(scope)
  scope:add_include('<any>')

  scope:add[[

template<typename T, typename V>
inline T as(V v) { return static_cast<T>(v); }

template<typename T>
inline T as(const std::any& v) { return std::any_cast<T>(v); }

]]
end

function builtins.table(scope)
  scope:add_include('<unordered_map>')
  scope:add_include('<vector>')
  scope:add_include('<any>')

  --#ifdef __clang__
  --#include <boost/functional/hash.hpp>
  --#include <boost/variant.hpp>
  --#else
  scope:add_include('<variant>')
  --#endif

  scope:add[[
struct table
{
    typedef std::any value_t;

#ifdef __clang__
    typedef boost::variant<long, double, std::string> key_t;
    typedef boost::hash<key_t> key_hasher_t;
#else
    typedef std::variant<long, double, std::string> key_t;
    typedef std::hash<key_t> key_hasher_t;
#endif

    typedef std::unordered_map<key_t, value_t, key_hasher_t> hashmap_t;
    typedef std::vector<value_t> array_t;

    array_t array;
    hashmap_t hashmap;

    table() {}

    table(array_t array, hashmap_t hashmap) :
        array(std::move(array)), hashmap(std::move(hashmap)) {}

    void shrink() {
        if(array.empty())
            return;
        while(!array.back().has_value())
            array.pop_back();
    }

    void insert(long pos, value_t value) {
        shrink();
        if(pos == (long)array.size() + 1) {
            if(!value.has_value())
                return;
            array.push_back(std::move(value));
        } else if(pos <= (long)array.size() && pos >= 1) {
            array.insert(array.begin() + (pos - 1), value);
        } else {
            throw std::out_of_range("bad argument to table 'insert' (position out of bounds)");
        }
    }

    void insert(value_t value) {
        if(!value.has_value())
            return;
        shrink();
        array.push_back(std::move(value));
    }

    static void insert(table& t, value_t value) { t.insert(std::move(value)); }

    value_t remove() {
        shrink();
        value_t v;
        if(array.empty())
            return v;
        v = std::move(array.back());
        array.pop_back();
        return v;
    }

    value_t remove(long pos) {
        shrink();
        value_t v;
        if(pos <= (long)array.size() && pos >= 1) {
            auto it = array.begin() + (pos - 1);
            v = std::move(*it);
            array.erase(it);
        } else {
            auto it = hashmap.find(pos);
            if(it != hashmap.end()) {
                v = std::move(it->second);
                hashmap.erase(it);
            }
        }
        return v;
    }

    void set(key_t pos, value_t value) {
        if(!value.has_value()) {
            auto it = hashmap.find(pos);
            if(it != hashmap.end())
                hashmap.erase(it);
        } else
            hashmap[pos] = std::move(value);
    }

    void set(long pos, value_t value) {
        shrink();
        if(pos == (long)array.size()+1) {
            if(value.has_value())
                array.push_back(std::move(value));
            else
                array.pop_back();
        } else if(pos <= (long)array.size() && pos >=  1) {
            array[pos-1] = std::move(value);
        } else {
            set(key_t(pos), std::move(value));
        }
    }

    value_t get(long pos) {
        if(pos <= (long)array.size() && pos >= 1) {
            return array[pos - 1];
        } else {
            auto it = hashmap.find(pos);
            if(it != hashmap.end())
                return it->second;
        }
        return value_t();
    }

    value_t get(key_t pos) {
        auto it = hashmap.find(pos);
        if(it != hashmap.end())
            return it->second;
        return value_t();
    }

    value_t& operator[](long pos) {
        if(pos == (long)array.size()+1) {
            array.push_back(value_t());
            return array.back();
        } else if(pos <= (long)array.size() && pos >= 1) {
            return array[pos-1];
        } else {
            return hashmap[pos];
        }
    }

    value_t& operator[](key_t pos) {
        return hashmap[pos];
    }

    size_t size() const {
        size_t len = array.size();
        for(auto it = array.rbegin(), end = array.rend(); it != end && !(*it).has_value(); ++it)
            len--;
        return len;
    }
};
]]
end

return builtins