import { CLIPS } from "./data"
import { Video, Window } from "./Window"

const REEL = [CLIPS.studio, CLIPS.couch, CLIPS.train, CLIPS.keys, CLIPS.react, CLIPS.night]

export function Everywhere() {
  return (
    <section className="desk-dots py-24">
      <div className="mx-auto max-w-6xl px-6">
        <h2 className="max-w-xl text-balance text-[40px] leading-[1.05] font-semibold tracking-[-0.03em] sm:text-[52px]">
          Right where you're working
        </h2>
        <p className="mt-4 max-w-md text-[18px] leading-relaxed text-quiet">
          On a rooftop, in a field, on the train, at 2am. Flare opens over whatever is on screen, and gets out of the way when you're done.
        </p>
      </div>
      <div
        className="no-scrollbar mt-12 flex snap-x snap-mandatory gap-6 overflow-x-auto pb-6"
        style={{ paddingInline: "max(1.5rem, calc((100vw - 72rem) / 2 + 1.5rem))", scrollPaddingInline: "max(1.5rem, calc((100vw - 72rem) / 2 + 1.5rem))" }}
      >
        {REEL.map((clip) => (
          <figure
            key={clip.title}
            className="flex w-[78vw] max-w-[440px] shrink-0 snap-start flex-col items-center gap-2.5"
          >
            <Window className="w-full">
              <div className="aspect-[16/10]">
                <Video clip={clip} />
              </div>
            </Window>
            <figcaption className="text-[13px] text-quiet">{clip.title}</figcaption>
          </figure>
        ))}
      </div>
    </section>
  )
}
