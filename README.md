# YSF

Compiled forth-like language

## Build
```
dub build
```

## Examples
### Hello world
```
include std.ysf

"hello world" putstr
exit
```

### If statement
```
include std.ysf

2 2 equal if
	"2 is 2" putstr
endif

exit
```

### Function
```
include std.ysl

function sayHello ( -- )
	"hello" putstr
endf
```

### Variables
```
variable myvar

myvar 5 poke ( write 5 to myvar )
myvar peek ( get variable's contents )
```

### Arrays
```
include std.ysf

array 6 myarray

myarray 65 poke
myarray 1 + 66 poke
myarray 2 + 67 poke
myarray 3 + 68 poke
myarray 4 + 69 poke
myarray 5 + 70 poke

myarray peek emit
myarray 1 + peek emit
myarray 2 + peek emit
myarray 3 + peek emit
myarray 4 + peek emit
myarray 5 + peek emit

exit
```
