export const en = {
  metadata: {
    title: "PhotoTend — Make photo organizing feel effortless",
    description: "Sort with simple gestures and keep the photos that matter.",
  },
  hero: {
    eyebrow: "PhotoTend",
    title: "Make photo organizing feel effortless.",
    body: "Browse, keep, or move photos to trash with intuitive gestures. No cleanup pressure—just more room for what matters.",
    cta: "Download for Android",
    note: "Available on Android. macOS and iPhone are coming soon.",
  },
  nav: {
    why: "Why PhotoTend",
    workflow: "How it works",
    platforms: "Platforms",
    github: "GitHub",
    join: "Download for Android",
  },
  gesture: {
    kicker: "Four directions. No menus to learn.",
    title: "One photo at a time. Soon, it all feels lighter.",
    body: "Turn every decision into an intuitive gesture. Everything goes to trash first, so you stay in control.",
    ariaLabel: "Photo organizing gestures",
    items: [
      { action: "Swipe left", detail: "See a random next photo", arrow: "←" },
      { action: "Swipe right", detail: "Return to the previous photo", arrow: "→" },
      { action: "Swipe up", detail: "Move it to trash first", arrow: "↑" },
      { action: "Swipe down", detail: "Undo the last move", arrow: "↓" },
    ],
  },
  imports: {
    kicker: "Beyond your phone library",
    title: "From your phone or your camera, bring it all together.",
    body: "Import photos and videos from external storage, then browse and organize them in one focused place.",
    ariaLabel: "Supported import sources",
    sources: ["Phone library", "Camera & memory card", "External storage", "Imported folders"],
  },
  features: {
    kicker: "Start with one small chapter",
    items: [
      {
        title: "You do not have to start at the beginning",
        body: "Filter by time and place. Begin with today, a trip, or somewhere familiar.",
        marker: "01",
      },
      {
        title: "Photos and videos stay together",
        body: "Review photos, videos, and motion photos in one continuous flow.",
        marker: "02",
      },
      {
        title: "There is room to change your mind",
        body: "Move things to trash first and restore them anytime. Permanent deletion only happens after confirmation.",
        marker: "03",
      },
    ],
  },
  philosophy: {
    title: "Not another cleanup task. A chance to see your photos again.",
    body: "Your library holds more than files taking up space. Tend to a few today and slowly keep more of what matters.",
  },
  platforms: {
    kicker: "Platforms",
    title: "Start on a device you already know.",
    items: [
      { name: "Android", status: "Direct download", tone: "ready" },
      { name: "macOS", status: "Coming soon", tone: "waiting" },
      { name: "iPhone", status: "Coming soon", tone: "waiting" },
    ],
  },
  finalCta: {
    title: "Open source, and staying that way.",
    body: "PhotoTend is built in the open. Explore the code, learn from it, and help shape a calmer way to care for your photo library.",
    download: "Download for Android",
    github: "View source on GitHub",
    license: "Licensed under GNU GPLv3. If you distribute a modified version, its source must remain available under the same license.",
  },
  footer: {
    tagline: "Organize lightly. Keep what matters.",
    privacy: "Privacy",
    github: "GitHub",
    contact: "Contact",
    copyright: "© 2026 PhotoTend",
  },
} as const;
