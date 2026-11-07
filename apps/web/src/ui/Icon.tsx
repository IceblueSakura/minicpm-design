export const Icon = ({ name, className = 'i' }: { name: string; className?: string }) => (
  <svg className={className} aria-hidden="true"><use href={`#i-${name}`} /></svg>
);

export const Mark = () => (
  <svg className="mark" viewBox="0 0 24 24" aria-hidden="true">
    <path className="a" d="M4 10.500V9M8 10.500V6M12 10.500V3.500M16 10.500V7.500M20 10.500V9.500" />
    <path className="b" d="M4 13.500V15M8 13.500V16.500M12 13.500V16M16 13.500V20.500M20 13.500V17" />
  </svg>
);
