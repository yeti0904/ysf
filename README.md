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
