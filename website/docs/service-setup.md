# PhotoTend 生产服务配置

目标地址：`https://phototend.onemorejack.top`

这份清单只记录配置位置、非敏感标识和验证方法。密码、API Key、Webhook Secret
以及三个令牌密钥不得写入仓库、Issue、聊天记录或截图。

## 1. Supabase

1. 在 `OneMoreJack's Org` 中创建名为 `phototend-marketing` 的项目。
2. 区域优先选择 Tokyo（Northeast Asia）。它兼顾中国大陆访问路径与海外服务之间的延迟；
   上线后仍需按生产验证清单分别实测境内和境外网络。
3. 生成独立的强数据库密码，并仅保存在密码管理器中。网站运行时不需要数据库密码。
4. 在 SQL Editor 中完整执行
   `supabase/migrations/202607260001_marketing_site.sql`。
5. 在 Table Editor 确认相关表已启用 RLS，且不存在匿名读取策略。
6. 在 Storage 确认 `releases` bucket 为 Private。
7. 从 Project Settings > API 取得 Project URL 和 server-only service role key。
   后者只能写入 Vercel 的加密环境变量。

完成验证：

- 匿名客户端不能读取 waitlist、release 或 download grant 数据。
- 未签名 URL 不能读取 `releases` 中的对象。
- SQL migration 中的唯一约束和枚举约束已存在。

## 2. Resend

1. 注册或登录 Resend。
2. 添加发送域名 `phototend.onemorejack.top`。
3. 把 Resend 页面给出的 SPF、DKIM（以及页面要求时的 MX）记录逐条写入
   `onemorejack.top` 当前 DNS 提供商。记录名和值必须以 Resend 页面为准。
4. 等待域名状态变为 Verified。
5. 创建仅供 PhotoTend 生产环境使用的 API Key。
6. 创建 Webhook，地址为：
   `https://phototend.onemorejack.top/api/webhooks/resend`
7. 订阅 `email.delivered`、`email.bounced`、`email.complained` 事件，并保存签名密钥。
8. 发件人使用 `PhotoTend <hello@phototend.onemorejack.top>`。

完成验证：

- Resend 域名、DKIM 和 SPF 均显示 Verified。
- 测试邮件 From 与 Reply/Support 地址正确。
- Webhook 的真实签名事件返回成功；伪造签名被拒绝。

## 3. Vercel

1. 新建项目 `phototend-marketing` 并连接此 Git 仓库。
2. Framework Preset 选择 Next.js，Root Directory 设置为 `website`。
3. Production 环境设置 `.env.example` 中的全部变量。
4. Preview 环境必须使用独立的 Supabase/Resend 测试资源或禁用真实发信；
   不要把生产 service role key 和 Resend key 暴露给不受信任的预览部署。
5. 在 Domains 中添加 `phototend.onemorejack.top`。
6. 将 Vercel 显示的精确 CNAME 或 A 记录写入当前 DNS 提供商。若该主机名已有记录，
   先确认目标后再替换，避免影响其他服务。
7. 等待 Vercel 显示域名 Valid Configuration，并确认 HTTPS 证书已签发。

环境变量填完后，在本地或 CI 的受保护环境中运行：

```bash
npm run verify:env
```

脚本只输出变量名和 `ready`、`missing`、`placeholder`、`invalid` 状态，不输出值。

## 4. DNS 与上线顺序

建议一次性完成以下 DNS 变更：

1. Vercel 要求的 `phototend` 主机记录。
2. Resend 要求的 DKIM、SPF 和可选 MX 记录。
3. 保持较低 TTL 直至生产验证完成；稳定后再恢复 DNS 提供商的常规 TTL。

上线顺序：

1. Supabase migration 与私有 bucket。
2. Resend 域名、API Key、Webhook。
3. Vercel 环境变量与首次生产部署。
4. Vercel 自定义域名和 DNS。
5. 上传已签名、已验证的 Android 安装包并激活 release 记录。
6. 验证无需邮箱即可完成 Android 直接下载。
7. 用指定测试邮箱完成版本通知订阅 → 确认邮件 → 退订闭环。

## 5. 非敏感交接记录

完成外部配置后，只在交接文档记录：

- Supabase project ref、区域和 migration 版本
- Vercel project 名称、production deployment ID 和域名状态
- Resend domain 状态与 webhook endpoint（不记录 secret）
- DNS 记录类型、主机名、验证状态和时间

任何密钥只保存在 Vercel 与密码管理器中。
