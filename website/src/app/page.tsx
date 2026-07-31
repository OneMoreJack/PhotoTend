import Link from "next/link";
import { androidDownloadUrl } from "@/lib/links";

export default function HomePage() {
  return (
    <main>
      <h1>理好相册 PhotoTend</h1>
      <p>轻松整理，留下真正重要的照片。</p>
      <Link href={androidDownloadUrl}>下载 Android 版</Link>
    </main>
  );
}
