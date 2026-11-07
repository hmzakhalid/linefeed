import { type PointerEvent, useRef } from "react";

export function PoeticScene() {
  const sceneRef = useRef<HTMLDivElement>(null);

  function moveScene(event: PointerEvent<HTMLDivElement>) {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const bounds = event.currentTarget.getBoundingClientRect();
    const x = (event.clientX - bounds.left) / bounds.width - 0.5;
    const y = (event.clientY - bounds.top) / bounds.height - 0.5;
    sceneRef.current?.style.setProperty("--pointer-x", `${x * 12}deg`);
    sceneRef.current?.style.setProperty("--pointer-y", `${y * -8}deg`);
  }

  function resetScene() {
    sceneRef.current?.style.setProperty("--pointer-x", "0deg");
    sceneRef.current?.style.setProperty("--pointer-y", "0deg");
  }

  return (
    <div
      ref={sceneRef}
      className="poetic-scene"
      role="img"
      aria-label="A tactile sculpture where a red thread connects voice, a circled screen moment, and a paper sentence"
      onPointerMove={moveScene}
      onPointerLeave={resetScene}
    >
      <span className="poetic-scene__halo" aria-hidden="true" />
      <span className="poetic-scene__orbit poetic-scene__orbit--voice" aria-hidden="true">
        <i /> listening
      </span>
      <span className="poetic-scene__orbit poetic-scene__orbit--moment" aria-hidden="true">
        00:12 / moment kept
      </span>
      <span className="poetic-scene__orbit poetic-scene__orbit--return" aria-hidden="true">
        ↵ ready
      </span>

      <svg className="poetic-scene__line" viewBox="0 0 1100 580" aria-hidden="true">
        <path d="M58 309C228 58 345 110 480 262C624 425 776 123 1034 292" />
      </svg>

      <div className="poetic-scene__asset" aria-hidden="true">
        <img
          src="./hero-thread-sculpture.webp"
          alt=""
          width="1536"
          height="1024"
          decoding="async"
          fetchPriority="high"
        />
      </div>

      <p className="poetic-scene__caption" aria-hidden="true">
        <span>VOICE</span>
        <span>CONTEXT</span>
        <span>THOUGHT</span>
      </p>
    </div>
  );
}
