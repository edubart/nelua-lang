; This file is used by our DSL, but it's not really Lisp.
; The 'lisp' extension is used just to enable syntax highlighting.
(print "Hello from DSL!")
(fn fib (n)
  (let a 0)
  (let b 1)
  (let i 0)
  (while (< i n)
    (let tmp a)
    (= a b)
    (= b (+ a tmp))
    (= i (+ i 1))
  )
  a
)
(let n (fib 10))
(print (.. "Fib 10 is " n))
