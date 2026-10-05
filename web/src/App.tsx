import { Footer, Models, Note, OpenSource } from "@/site/Closing"
import { Features } from "@/site/Features"
import { Showcase } from "@/site/Showcase"
import { Hero } from "@/site/Hero"
import { MenuBar } from "@/site/MenuBar"
import { Shortcuts } from "@/site/Shortcuts"

export default function App() {
  return (
    <div className="min-h-screen bg-desk text-ink">
      <MenuBar />
      <main>
        <Hero />
        <section className="desk-dots px-4 pb-28 sm:px-6">
          <div className="mx-auto max-w-6xl">
            <Showcase />
          </div>
        </section>
        <Features />
        <Shortcuts />
        <Models />
        <Note />
        <OpenSource />
      </main>
      <Footer />
    </div>
  )
}
