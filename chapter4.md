# The first version of Rust bindings in syslog-ng

I created bindings for filters and parsers. Filters are the simplest components
of syslog-ng, so they were good subjects to start with. The final result
supports only parsers, because they can work as filters and my libraries can be
integrated as parsers.

## The first version of Rust bindings in syslog-ng

I created bindings for filters and parsers. Filters are the simplest components
of syslog-ng so they were good subjects to start with. 

### Filters

Filters can filter out the incoming data. The `ParserRust` class is inherited
from the `FilterExprNode` class. It registers its methods as callbacks on its
`super` which forwards the calls into a `RustFilterProxy` object. That holds
a pointer to a `RustFilter` trait object.

The `RustFilter` traits definition is as follows:

```Rust
pub trait RustFilter {
    fn init(&mut self, _: &GlobalConfig) {}
    fn eval(&self, msg: &mut LogMessage) -> bool;
    fn set_option(&mut self, key: String, value: String);
}
```

The class diagram is depicted on the following picture.

![RustFilter](rust_filter.pdf)

`FilterExprNode` and `FilterRust` are defined in `C` while `RustFilter`
and `RustFilterProxy` are defined in Rust.

Filters are not so important as parsers, because a parser can substitute filters
in many ways.

### Parsers

Parsers are able to parse messages into key-value pairs. The `ParserRust` class has a pointer to a
`RustParserProxy` object. `ParserRust` is defined in C while `RustParserProxy` is
a Rust object. 

The `RustParserProxy` has a `parser` pointer member which holds a `RustParser`
trait object. `ParserRust` registers its functions on its ancestor `LogPipe` as
callbacks.  Those functions forwards the execution through the `RustParserProxy`
pointer, which also forwards them to the trait object.

`RustParserProxy` is needed, because trait objects are behind a fat pointer.
They cannot be passed to the C side without wrapping them in a `struct`. The
`struct`'s memory representation is the same as it would be a C struct: the
`#[repr(C)]` attribute takes care about this.

The definition of the `RustParser` trait is the following:

```Rust
pub trait RustParser {
    fn init(&mut self) -> bool { true }
    fn set_option(&mut self, _: String, _: String) {}
    fn process(&mut self, msg: &mut LogMessage, input: &str) -> bool;
    fn boxed_clone(&self) -> Box<RustParser>;
}
```

The class diagram is depicted on the following picture.

![RustParser](rust_parser.pdf)

## The current Rust bindings

The first design was simple but had some flaws:

1. there was one big `syslog-ng-rust-modules` library which contained all modules
  written in Rust,
2. a filter/parser didn't know its parent, it couldn't call its parent's
  functions,
3. `syslog-ng-sys` wasn't an independent crate and provided some
  higher level bindings.

The current Rust bindings solve these problems, but without the first version I
wouldn't be able to realize them at all. So the first binding version was a
necessary step towards the more usable and flexible bindings.

### Having `1:1` mapping between modules and Rust modules
The ideal solution for the first problem is having a 1:1 mapping between Rust
and C modules. This means that each Rust module has its own crate and the build
result is a `lib*.so` file which can be copied into syslog-ng's module
directory.

This solution introduces the following problems:

1. Every plugin has to have its own grammar:
 * writing bindings for the grammar is a huge and tedious work,
 * compiling the grammar needs well parameterized grammar generators,
 * the grammar calls exported functions, their redeclarations look like boilerplate code.
1. The `module_info` `struct` has to be generated:
 * module and plugin names are null terminated strings which cannot be created
    with Rust in static variables or constants,
 * the `module_info` `struct` is expected to be static.
1. The code which connects Rust and C halves looks like boilerplate.

The first problem can be solved if syslog-ng creates a static library which
contains the generated grammar and the Rust modules link against this library.
Unfortunately, I discovered a
[bug](https://github.com/balabit/syslog-ng/issues/714) in syslog-ng's
plugin/grammar system which blocked this solution. After fixing It, I was able
to generate this static library, but it didn't work as expected. The problem
was, that this static library was linked into several shared libraries (each
one of them was a Rust module). The static library exported some public
symbols which were present in these shared libraries, so when syslog-ng opened
them the linker resolved these symbols only once. The result was, that only
the first loaded Rust module was effective, all the subsequently loaded modules
was mapped to the first one.

The solution was to force the compiler to generate hidden symbols which aren't
visible outside of the created library. If the object files are compiled with
the `-fvisibility=hidden` parameter, the
`__attribute__((visibility("hidden")))` attribute is applied to the
**non-extern** symbols. The `extern` functions (as well as the forward function
declarations) have to be marked explicitly with this attribute. Finally, the
static library doesn't export any public symbols but if it's linked into a
shared library, its undefined symbols are resolved from the shared library.

This static library references functions which has to be present in the final
`.so` library. These functions are my `proxy` functions in Rust:

* `native_parser_proxy_new()`: creates a new proxy instance,
* `native_parser_proxy_free()`: frees a proxy instance,
* `native_parser_proxy_clone()`: clones a proxy instance,
* `native_parser_proxy_set_option()`: sets a key-value configuration option on a proxy instance,
* `native_parser_proxy_init()`: initializes the proxy based on the previously set configuration options,
* `native_parser_proxy_process()`: parses an input string.

A Rust module defines these symbols so when the linker copies the static library
into the shared library, the symbols are resolved internally (hidden visibility).

The second problem can be solved if the Rust module generates a `module.c` file
with the `module_info` variable, then compiles it into a static library and
uses it for linking. This generation can be done with a build script which is
supported by Cargo. The `pkg-config` and `gcc` programs have already have
bindings so they can be used by the build script. I created a `create_module()` function
which does the module definition generation and compilation. Unfortunately,
compilation requires some macros to be defined which are not available
if syslog-ng is installed from a package. These macros are generated when syslog-ng
is configured via its `configure` script and placed in the `config.h` file. 
This file is not distributed with good reason: if it gets included into a third
application, it can overwrite the application's own macros. I solved this problem
by prefixing all generated macros with `SYSLOG_NG` (with using the `AX_PREFIX_CONFIG_H`
macro) and distributing `config.h` as `syslog-ng-config.h`.

The third problem is solved by moving all boilerplate code into a macro and a function.
I'll present them later, when the Rust half of the architecture is described.

### The Rust part

A single parser interface presents a problem, at least is Rust. Let's assume
we would like to create a parser, which requires its own configuration file (`F`),
an URL (`U`) and has two other optional parameters (`A` and `B`). By instinct,
we would map this parser into this struct definition:

```rust
struct DummyParser {
    F: ConfigurationFile,
    U: URL,
    A: Option<String>,
    B: Option<String>,
}
```

This definition clearly states, that `F` and `U` are required options and `A` and `B`
are optional ones. In Rust, when a struct is instantiated, all of its fields have to be initialized
with a valid value. `A` and `B` can get the `None` value, but what should happen with `F` and `U`?
Other languages, like `Java`, would use the `null` value there. We can also define them
as optional values:

```rust
struct DummyParser {
    F: Option<ConfigurationFile>,
    U: Option<URL>,
    A: Option<String>,
    B: Option<String>,
}
```

Everything is optional so we can instantiate the struct with only `None` values.
Let's see, how would a `parse()` call look like:

```rust
fn parse(&mut self, input: &str) -> bool {
    if let Some(f) = self.F.as_ref() {
        if let Some(u) = self.U.as_ref() {
            // do the parsing here
        } else {
            // ???
        }
    } else {
        // ???
    }
}
```

I marked the interesting lines with the `???` comment. We know, that when
`parse()` is called the parser should be initialized, but we must represent
the required fields with optional values, because of the initialization
process. This is really ugly, so I had to come up with something more clever.

I split the single parser interface into two halves. The first half handles
the initialization process and when everything is set, it builds the parser
instance in one step. The parser definition uses `Option<T>s` only
for the optional values.

The `ParserBuilder` trait is responsible for building a `Parser`
instance based on the configuration options. The definition of these traits
are as follows:

```rust
pub trait ParserBuilder: Clone {
    type Parser: Parser;
    fn new() -> Self;
    fn option(&mut self, name: String, value: String);
    fn parent(&mut self, _: *mut LogParser) {}
    fn build(self) -> Result<Self::Parser, OptionError>;
}

pub trait Parser: Clone {
    fn parse(&mut self, msg: &mut LogMessage, input: &str) -> bool;
}
```

Each parser should implement the `Parser` trait. It contains
only a `parse()` method, which parses an input string and returns the result
of the parsing.

`Parsers` are created by their corresponding `ParserBuilder` implementation.
They are instantiated without parameters and the configuration options are
set through the `option()` method. The `parent()` method sets the parent of
this parser, in fact it is a pointer to a C struct. It is generally not needed,
but there may be use-cases for accessing it from Rust in the future. The
`build()` method builds either a parser or returns an error and it consumes
itself in the process. Note, that Rust's type system constraints the type of
the built parser: a given builder can build only one specific parser type and
this constraint is built into the interface itself.

The missing piece is the type which actually forwards the calls from the
C side to the Rust parser instance. It is defined as follows:

```rust
#[repr(C)]
#[derive(Clone)]
pub struct ParserProxy<B> where B: ParserBuilder {
    pub parser: Option<B::Parser>,
    pub builder: Option<B>
}
```

It is generic over a B parameter, which must implement the `ParserBuilder`
trait.  Note, that the proxy knows the type of the parser field. This leads to
increased performance, because the method calls can be statically dispatched or
even inlined. If the parser has no size (like `struct Foo;`) the compiler can
further optimize the code.

I created a macro to generate the definitions of the `native_parser_proxy_*()`
functions. The `parser_plugin!` macro takes a `ParserBuilder` implementation as
its parameter and generates these functions, such as 

```rust
#[no_mangle]
pub extern fn native_parser_proxy_free(_: Box<ParserProxy<$name>>) {
}
```

The `$name` parameter is the name of the type which was passed to the `parser_plugin!` macro.

The `module_info` structure is generated in a build script. The `create_module()` function
is responsible for generating the module structure.

I split the Rust code into three separate crates:

* `syslog-ng-sys` contains the low level FFI bindings,
* `syslog-ng-common` contains the high level traits, such as `Parser`,
* `syslog-ng-build` contains the `create_module()` function.

The build process of a Rust module is as follows:
1. the Rust compiler (`rustc`) compiles the build script, then executes it:
 1. the build script looks for the `libsyslog-ng-native-connector.a` file (via `pkg-config`) and adds it to the linker search path,
 1. the build script generates a `module.c` file, compiles it into a `librust-module.a` file and adds it to the linker search path.
1. rustc compiles the parser implementation,
1. rustc expands the macro invocation into the `native_parser_proxy_*()` function,
1. rustc generates a `lib<name>.so` file.

The result is a shared library which can be immediately copied into syslog-ng's module directory.

![The architecture of Rust parser](current_parser.pdf)

