# TinyColourConverter

Tiny utility that converts [input] (rgb/hex) into [output]

## Input

- Accepts rgb (as csv)
- Accepts hex

## Output

- rgb
- hex
- int

### CLI

```bash
Options:
  -e  / --entries | Required for multiple value input
  -d  / --dump    | Takes filepath, output values to there instead of Notify

Flags:
  -x  / --hex     | Output only the hex value(s)
  -fx / --fhex    | Output only the formatted hex value(s)
  -i  / --int     | Output only the c.int value(s)

Notes:
  By default, tcc will print all conversion data, if no flags are given.
  The -e option must always be the final argument, before the input values

  If using only one input, no flags are specified, the -e is optional

Examples:
  tcc 40,50,60
  tcc -e "#A19FC4" 35,60,70
  tcc -fx -e 90,60,20 120,200,160 "#A49C93"
  tcc -d $PWD/list -i -e 145,26,94

```

### Todo

- Adding some extra validation on input
- Adding stdin passthrough, splitting on new line
