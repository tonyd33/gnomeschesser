import gleam/dict.{type Dict}
import gleam/list

pub fn zip_dict_by(xs: List(v), f: fn(v) -> k) -> Dict(k, v) {
  xs |> list.map(fn(x) { #(f(x), x) }) |> dict.from_list
}
