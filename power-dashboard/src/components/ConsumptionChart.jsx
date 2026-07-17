import { useState } from 'react'
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from 'recharts'

const data = [
  { time: '00:00', kW: 42 }, { time: '02:00', kW: 38 }, { time: '04:00', kW: 35 },
  { time: '06:00', kW: 48 }, { time: '07:00', kW: 58 }, { time: '08:00', kW: 64 },
  { time: '09:00', kW: 66 }, { time: '10:00', kW: 68 }, { time: '11:00', kW: 67 },
  { time: '12:00', kW: 63 }, { time: '13:00', kW: 60 }, { time: '14:00', kW: 62 },
  { time: '15:00', kW: 65 }, { time: '16:00', kW: 66 }, { time: '17:00', kW: 62 },
  { time: '18:00', kW: 55 }, { time: '20:00', kW: 48 }, { time: '22:00', kW: 44 },
]

const weekData = [
  { time: 'Mon', kW: 58 }, { time: 'Tue', kW: 62 }, { time: 'Wed', kW: 55 },
  { time: 'Thu', kW: 65 }, { time: 'Fri', kW: 60 }, { time: 'Sat', kW: 45 },
  { time: 'Sun', kW: 42 },
]

export default function ConsumptionChart() {
  const [range, setRange] = useState('today')
  const chartData = range === 'today' ? data : weekData
  const contractDemand = 400

  return (
    <div className="bg-white border border-border rounded-xl p-5">
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-heading font-semibold text-text-primary">
          Consumption Trend
        </h3>
        <div className="flex gap-1 p-0.5 rounded-lg bg-surface border border-border">
          {['today', 'week'].map((r) => (
            <button
              key={r}
              onClick={() => setRange(r)}
              className={`px-3 py-1 rounded-md text-xs font-medium transition-colors ${
                range === r
                  ? 'bg-lime text-on-lime'
                  : 'text-text-muted hover:text-text-primary'
              }`}
            >
              {r === 'today' ? 'Today' : 'Week'}
            </button>
          ))}
        </div>
      </div>

      <div className="h-56">
        {chartData.length === 0 ? (
          <div className="h-full flex items-center justify-center text-text-muted text-sm">
            No consumption data available
          </div>
        ) : (
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={chartData} margin={{ top: 5, right: 5, left: -20, bottom: 0 }}>
              <defs>
                <linearGradient id="limeFill" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#C3D809" stopOpacity={0.35} />
                  <stop offset="100%" stopColor="#C3D809" stopOpacity={0.02} />
                </linearGradient>
              </defs>
              <CartesianGrid stroke="#E4E6D0" strokeDasharray="3 3" vertical={false} />
              <XAxis dataKey="time" axisLine={false} tickLine={false} tick={{ fill: '#8A8C7E', fontSize: 11, fontFamily: 'Inter' }} />
              <YAxis axisLine={false} tickLine={false} tick={{ fill: '#8A8C7E', fontSize: 11, fontFamily: 'JetBrains Mono' }} unit=" kW" domain={[0, 'auto']} />
              <Tooltip
                contentStyle={{
                  background: '#FFFFFF',
                  border: '1px solid #E4E6D0',
                  borderRadius: 8,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  color: '#3A3A32',
                }}
                formatter={(value) => [`${value} kW`]}
              />
              <ReferenceLine
                y={contractDemand}
                stroke="#D64545"
                strokeDasharray="6 4"
                strokeWidth={1.5}
                label={{
                  value: `Contract Demand (${contractDemand} kW)`,
                  fill: '#D64545',
                  fontSize: 10,
                  fontFamily: 'Inter',
                  position: 'right',
                }}
              />
              <Area
                type="monotone"
                dataKey="kW"
                stroke="#C3D809"
                strokeWidth={2}
                fill="url(#limeFill)"
                dot={false}
                activeDot={{ r: 4, fill: '#C3D809', stroke: '#FFFFFF', strokeWidth: 2 }}
              />
            </AreaChart>
          </ResponsiveContainer>
        )}
      </div>
    </div>
  )
}
