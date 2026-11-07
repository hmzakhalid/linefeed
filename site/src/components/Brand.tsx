import mark from "../assets/mark.svg?raw";

type BrandProps = {
  inverse?: boolean;
};

export function Brand({ inverse = false }: BrandProps) {
  return (
    <a className={`brand${inverse ? " brand--inverse" : ""}`} href="#top" aria-label="Linefeed home">
      <span className="brand__mark" aria-hidden="true" dangerouslySetInnerHTML={{ __html: mark }} />
      <span>Linefeed</span>
    </a>
  );
}
