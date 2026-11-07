export function MemoryScene() {
  return (
    <div
      className="memory-scene"
      role="img"
      aria-label="Two captured screen moments remain tied to the words spoken at twelve seconds and twenty-four seconds"
    >
      <div className="memory-scene__glow" aria-hidden="true" />
      <img
        src="./memory-thread-sculpture.webp"
        alt=""
        width="1024"
        height="1536"
        loading="lazy"
        decoding="async"
      />

      <div className="memory-note memory-note--first" aria-hidden="true">
        <small>00:12 / MOMENT 01</small>
        <p>“Move this closer.”</p>
      </div>
      <div className="memory-note memory-note--second" aria-hidden="true">
        <small>00:24 / MOMENT 02</small>
        <p>“Keep this beside it.”</p>
      </div>
      <span className="memory-scene__local" aria-hidden="true"><i /> saved on this Mac</span>
    </div>
  );
}
