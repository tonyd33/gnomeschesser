project(
  'polyglot-operator',
  'cpp',
  default_options: [
    'cpp_std=c++20',
    'optimization=3',
    'warning_level=everything',
  ],
)

sources = files(
  'src/pg_builder.cc',
  'src/polyglot.cc',
  'src/util.cc',
)

cxx = meson.get_compiler('cpp')

executable(
  'polyglot-operator',
  [
    files('src/main.cc'),
    sources
  ],
)
