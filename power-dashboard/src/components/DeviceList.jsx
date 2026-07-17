import { Cpu, Fan, Wind, Lightbulb, Cog } from 'lucide-react'

const devices = [
  { name: 'Air Compressor', kW: 22.4, icon: Fan, progress: 72, warning: false },
  { name: 'Main Motor Line', kW: 18.6, icon: Cog, progress: 60, warning: false },
  { name: 'HVAC — Shop Floor', kW: 12.5, icon: Wind, progress: 40, warning: true },
  { name: 'Lighting Grid', kW: 7.9, icon: Lightbulb, progress: 25, warning: false },
  { name: 'Auxiliary Load', kW: 4.6, icon: Cpu, progress: 15, warning: false },
]

export default function DeviceList() {
  return (
    <div className="bg-white border border-border rounded-xl p-5 h-full">
      <h3 className="font-heading font-semibold text-text-primary mb-4">
        Device Breakdown
      </h3>

      <div className="space-y-4">
        {devices.map((d) => {
          const Icon = d.icon
          const pct = (d.kW / 22.4) * 100
          return (
            <div key={d.name}>
              <div className="flex items-center gap-3 mb-1.5">
                <div className="w-8 h-8 rounded-lg bg-surface flex items-center justify-center shrink-0">
                  <Icon size={16} className={d.warning ? 'text-danger' : 'text-text-muted'} />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium text-text-primary truncate">
                      {d.name}
                    </span>
                    <span className="font-mono text-sm font-semibold text-text-primary shrink-0 ml-2">
                      {d.kW}
                      <span className="font-body font-normal text-text-muted text-xs ml-0.5">kW</span>
                    </span>
                  </div>
                </div>
              </div>

              {/* Progress bar */}
              <div className="h-1.5 rounded-full bg-surface overflow-hidden">
                <div
                  className={`h-full rounded-full transition-all ${
                    d.warning ? 'bg-danger' : 'bg-lime'
                  }`}
                  style={{ width: `${pct}%` }}
                />
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
