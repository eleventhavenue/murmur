"use client";

import { useState } from "react";
import Image from "next/image";

const themes = [
  { id: "kinetic", label: "Kinetic", icon: "/theme-icons/kinetic.png" },
  { id: "serif", label: "Serif", icon: "/theme-icons/serif.png" },
  { id: "lilac", label: "Lilac", icon: "/theme-icons/lilac.png" },
];

export function ThemeToggle() {
  const [active, setActive] = useState("serif");

  const handleTheme = (id: string) => {
    setActive(id);
    document.documentElement.setAttribute("data-theme", id);
  };

  return (
    <div className="flex items-center gap-3">
      {themes.map((t) => (
        <button
          key={t.id}
          onClick={() => handleTheme(t.id)}
          title={t.label}
          className={`
            relative w-10 h-10 rounded-full flex items-center justify-center transition-all cursor-pointer
            ${active === t.id
              ? "opacity-100 scale-110"
              : "opacity-40 hover:opacity-70"
            }
          `}
        >
          <Image
            src={t.icon}
            alt={t.label}
            width={36}
            height={36}
            className="object-contain"
            unoptimized
          />
        </button>
      ))}
    </div>
  );
}
