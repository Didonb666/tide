module github.com/tide/client-core

go 1.23.0

require github.com/metacubex/mihomo v1.19.33

// mihomo 自己的 go.mod 里有一条 replace（protobuf 换成了 metacubex 的 fork）。
// 依赖模块里的 replace 会被 Go 忽略，所以这里必须原样再写一遍，
// 否则会去用上游 protobuf，可能缺少 mihomo 需要的字段而编译失败。
replace google.golang.org/protobuf => github.com/metacubex/protobuf-go v0.0.0-20260306035419-7ceee0674686
