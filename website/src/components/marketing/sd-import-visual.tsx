export function SdImportVisual() {
  return (
    <svg
      className="sd-import-visual"
      data-testid="sd-import-visual"
      viewBox="0 0 640 430"
      role="img"
      aria-labelledby="sd-import-title"
    >
      <title id="sd-import-title">Photos importing from an SD card</title>
      <defs>
        <linearGradient id="sd-card-face" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#3b3935" />
          <stop offset="1" stopColor="#242321" />
        </linearGradient>
        <linearGradient id="sd-contact" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#f1d18d" />
          <stop offset="1" stopColor="#ad6f32" />
        </linearGradient>
        <clipPath id="photo-a">
          <rect x="0" y="0" width="64" height="76" rx="7" />
        </clipPath>
      </defs>

      <path
        className="sd-import-visual__trail"
        data-testid="sd-transfer-path"
        d="M182 231 C275 231 322 231 424 231"
        fill="none"
        pathLength="1"
      />

      <g className="sd-card">
        <path
          data-testid="sd-card-outline"
          d="M63 82 H174 L214 122 V330 Q214 348 196 348 H63 Q45 348 45 330 V100 Q45 82 63 82Z"
          fill="url(#sd-card-face)"
          stroke="#6b645a"
          strokeWidth="3"
        />
        <path
          d="M174 83 V122 H213"
          fill="#1d1c1a"
          stroke="#6b645a"
          strokeWidth="2"
        />
        <rect x="45" y="151" width="14" height="74" rx="3" fill="#171716" />
        <rect x="48" y="161" width="7" height="22" rx="2" fill="#b95b34" />
        <g data-testid="sd-card-contacts" transform="translate(76 101)">
          {[0, 18, 36, 54, 72, 90, 108, 126].map((x, index) => (
            <path
              key={x}
              d={`M${x} 0 H${x + 12} L${x + 9} ${index % 2 === 0 ? 45 : 51} H${x + 1}Z`}
              fill="url(#sd-contact)"
            />
          ))}
        </g>
        <rect x="70" y="213" width="119" height="82" rx="8" fill="#f3eee5" />
        <text x="82" y="240" fill="#a64b28" fontSize="13" fontWeight="800">
          PHOTOTEND
        </text>
        <text x="82" y="273" fill="#171a1c" fontSize="34" fontWeight="900">
          SD
        </text>
        <text x="157" y="276" fill="#655f57" fontSize="12" fontWeight="800">
          128 GB
        </text>
        <path d="M70 312 H188" stroke="#777067" strokeWidth="2" />
        <path d="M80 319 H178" stroke="#46433f" strokeWidth="2" />
      </g>

      {[0, 1, 2].map((index) => (
        <g
          className="sd-transfer__photo"
          data-testid="sd-traveling-photo"
          data-index={index}
          key={index}
          transform={`translate(${240 + index * 68} 193)`}
        >
          <g className="sd-transfer__photo-motion">
            <rect width="64" height="76" rx="7" fill="#f4f0e8" />
            <g clipPath="url(#photo-a)">
              <rect
                width="64"
                height="76"
                fill={index === 1 ? "#8aa3a0" : "#dca77d"}
              />
              <circle cx="47" cy="19" r="9" fill="#f5d78a" />
              <path
                d="M-5 58 Q18 31 39 49 T70 45 V80 H-5Z"
                fill={index === 2 ? "#4f2d24" : "#7e4936"}
              />
            </g>
            <rect
              x="0.75"
              y="0.75"
              width="62.5"
              height="74.5"
              rx="6.25"
              fill="none"
              stroke="#fffcf6"
              strokeWidth="1.5"
            />
          </g>
        </g>
      ))}

      <g className="sd-import-visual__album" transform="translate(455 123)">
        <rect x="24" y="22" width="132" height="164" rx="18" fill="#d88962" />
        <rect x="12" y="11" width="132" height="164" rx="18" fill="#e9b194" />
        <rect width="132" height="164" rx="18" fill="#a64b28" />
        <path
          d="M0 112 Q38 68 75 100 T132 88 V164 H0Z"
          fill="#7e351f"
          opacity="0.72"
        />
        <circle cx="96" cy="48" r="19" fill="#f4c86f" />
        <rect x="25" y="137" width="82" height="9" rx="4.5" fill="#f4f0e8" />
      </g>
    </svg>
  );
}
