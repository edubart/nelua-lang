runbench() {
euluna -br -g c --cflags="-O3" benchmarks/$1.euluna
euluna -br -g lua benchmarks/$1.euluna

#echo $1 lua5.3 && time lua5.3 ./euluna_cache/benchmarks/$1.lua
#echo $1 lua5.1 && time lua5.1 ./euluna_cache/benchmarks/$1.lua
echo $1 luajit && time luajit ./euluna_cache/benchmarks/$1.lua
echo $1 c &&      time        ./euluna_cache/benchmarks/$1
}

runbench mandel
runbench fibonacci
runbench ackermann
