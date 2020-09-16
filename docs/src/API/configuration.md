```@meta
CurrentModule = Configuration(配置文件模块)
```

```@docs
#### mutable struct:
+ GENIE_VERSION(Genie版本-常量)
+ Settings(应用程序配置-设置应用程序的默认设置)
#### function:
+ isdev(判断是否为开发环境函数)
+ isprod(判断是否为生成环境函数)
+ istest(判断是否为测试环境函数)
+ env(获取当前环境字符串函数, 如: "dev")
+ buildpath(获取构建temp目录路径函数)
```
