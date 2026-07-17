import { Menu, Search, Bell, User, Sun, Moon } from 'lucide-react'

export default function Header({ onMenuClick, title, dark, onToggleDark }) {
  return (
    <header className="h-16 shrink-0 bg-lime flex items-center px-4 lg:px-8 gap-4">
      <button className="md:hidden text-on-lime" onClick={onMenuClick}>
        <Menu size={22} />
      </button>

      <h1 className="font-heading font-bold text-lg text-on-lime shrink-0">
        {title}
      </h1>

      <div className="hidden sm:flex items-center gap-1.5 px-3 py-1 rounded-full bg-on-lime/10 text-on-lime text-xs font-medium">
        <span className="w-1.5 h-1.5 rounded-full bg-on-lime animate-pulse" />
        Live
      </div>

      <div className="flex-1" />

      <div className="hidden md:flex items-center gap-2 px-3 py-1.5 rounded-lg bg-on-lime/10 text-on-lime/70 min-w-[200px]">
        <Search size={15} />
        <input
          type="text"
          placeholder="Search meters..."
          className="bg-transparent border-none outline-none text-sm text-on-lime placeholder:text-on-lime/50 w-full"
        />
      </div>

      <button onClick={onToggleDark} className="text-on-lime" title="Toggle theme">
        {dark ? <Sun size={20} /> : <Moon size={20} />}
      </button>

      <button className="relative text-on-lime">
        <Bell size={20} />
        <span className="absolute -top-1 -right-1 w-2 h-2 rounded-full bg-danger" />
      </button>

      <div className="w-8 h-8 rounded-full bg-on-lime/20 flex items-center justify-center text-on-lime text-sm font-semibold">
        <User size={16} />
      </div>
    </header>
  )
}
