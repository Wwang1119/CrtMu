# CrtMu App Store 上架检查清单

这份清单只关注“先上架第一版”的最少动作。

## 1. 后端

- [ ] 后端已部署到公网
- [ ] 后端已开启 HTTPS
- [ ] `GET /health` 正常
- [ ] Flutter 正式包使用的是正式后端域名，而不是 `localhost`

正式打包命令示例：

```bash
flutter build ipa \
  --release \
  --dart-define=BACKEND_BASE_URL=https://api.你的域名.com
```

## 2. iOS 工程

当前项目里已经补好的内容：

- App 名称：`CrtMu`
- 图标：已接入
- 相册权限文案：已补到 `ios/Runner/Info.plist`

你仍然需要确认的内容：

- [ ] `Bundle Identifier` 换成你自己的正式包名
- [ ] `Version` / `Build` 设置正确
- [ ] Apple 开发者账号证书与签名正常

当前工程里的包名还是示例值：

`com.example.artAssistant`

正式上架前建议改成类似：

`com.你的品牌.crtmu`

## 3. App Store Connect

- [ ] 创建新的 App 记录
- [ ] 绑定正式 Bundle Identifier
- [ ] 上传 App 图标、截图、简介、关键词
- [ ] 填写隐私信息
- [ ] 填写年龄分级
- [ ] 如使用登录、会员、支付，补充相应说明

## 4. 第一次提审建议

第一版建议尽量简单：

- 先上“聊天 + 发图点评 + 基础档案”
- 会员和参考图生成可以放到后续版本
- 审核阶段尽量避免半成品入口

## 5. 真机提审前自测

- [ ] 冷启动正常
- [ ] 开场白正常展示
- [ ] 文本发送正常
- [ ] 选择相册图片正常
- [ ] 网络异常时能弹出错误提示
- [ ] 聊天缓存正常恢复
- [ ] 深色界面显示正常
