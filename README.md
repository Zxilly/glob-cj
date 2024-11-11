# glob-cj

[![Tests](https://github.com/Zxilly/glob-cj/actions/workflows/test.yml/badge.svg)](https://github.com/Zxilly/glob-cj/actions/workflows/test.yml)
[![codecov](https://codecov.io/github/Zxilly/glob-cj/graph/badge.svg?token=NAA9HM8BQE)](https://codecov.io/github/Zxilly/glob-cj)
![Static Badge](https://img.shields.io/badge/%E4%BB%93%E9%A2%89-green)

适用于仓颉的 glob 库，参照 [glob](https://github.com/rust-lang/glob) 开发

## 用法

在依赖中添加：

```toml
[dependencies]
glob = { git = "https://github.com/Zxilly/glob-cj.git", branch = "master" }
```

然后在代码中使用：

```cangjie
import glob

main(): Int64 {
    for (i in glob.glob("*")) {
        println(i)
    }

    return 0
}
```

## 文档

请查看 [文档](https://glob.cj.zxilly.dev)