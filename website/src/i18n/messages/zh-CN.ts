export const zhCN = {
  metadata: {
    title: "理好相册 PhotoTend",
    description: "轻松整理，留下真正重要的照片。",
  },
  hero: {
    eyebrow: "理好相册 PhotoTend",
    title: "让整理照片，变成一件顺手的小事。",
    body: "用直觉手势快速浏览、保留或移入回收站。不催你清空相册，只帮你留下真正重要的照片。",
    cta: "下载 Android 版",
    note: "目前支持 Android。macOS 与 iPhone 版本 Coming soon。",
  },
  nav: {
    why: "为什么是 PhotoTend",
    workflow: "如何使用",
    platforms: "支持平台",
    join: "下载 Android 版",
  },
  gesture: {
    kicker: "四个方向，不用学菜单",
    title: "一张一张，轻松理好。",
    body: "把判断变成直觉动作。所有删除都先进入回收站，想清楚之后，再统一处理。",
    ariaLabel: "手势整理方式",
    items: [
      { action: "左滑", detail: "随机看看下一张", arrow: "←" },
      { action: "右滑", detail: "回到刚刚看过的照片", arrow: "→" },
      { action: "上滑", detail: "先放进回收站", arrow: "↑" },
      { action: "下滑", detail: "撤销刚才的操作", arrow: "↓" },
    ],
  },
  imports: {
    kicker: "不只整理手机相册",
    title: "手机里的，相机里的，都可以一起理好。",
    body: "从外部存储导入照片和视频，在 PhotoTend 中集中浏览和整理。无论是一次旅行的手机随拍，还是相机存储卡里的素材，都能从同一个地方开始。",
    ariaLabel: "支持的导入来源",
    sources: ["手机系统相册", "相机与存储卡", "移动存储设备", "外部文件夹"],
  },
  features: {
    kicker: "从一小段回忆开始",
    items: [
      {
        title: "整理不用从头开始",
        body: "按时间和地点筛选，从今天、一次旅行，或者一个熟悉的地方开始。",
        marker: "01",
      },
      {
        title: "照片和视频一起看",
        body: "不必在不同工具之间切换，照片、视频和动态照片都能在同一条浏览流中处理。",
        marker: "02",
      },
      {
        title: "给反悔留出空间",
        body: "先移入回收站，随时恢复。只有最后确认时，才会永久删除。",
        marker: "03",
      },
    ],
  },
  philosophy: {
    title: "不是清理任务，是重新看看你的照片。",
    body: "相册里不只有占用空间的文件，也有忘记整理的日常。今天理一点，慢慢留下真正想保存的内容。",
  },
  platforms: {
    kicker: "支持平台",
    title: "在熟悉的设备上开始。",
    items: [
      { name: "Android 版", status: "可直接下载", tone: "ready" },
      { name: "macOS", status: "Coming soon", tone: "waiting" },
      { name: "iPhone", status: "Coming soon", tone: "waiting" },
    ],
  },
  finalCta: {
    title: "订阅版本通知",
    body: "邮箱完全可选。我们会在新版本，以及 macOS 或 iPhone 版本开放时通知你。",
    cta: "订阅更新",
    privacy: "只发送重要版本通知，不影响 Android 直接下载。你可以随时退订。",
  },
  footer: {
    tagline: "轻松整理，留下真正重要的照片。",
    privacy: "隐私政策",
    contact: "联系我们",
    copyright: "© 2026 PhotoTend",
  },
} as const;
