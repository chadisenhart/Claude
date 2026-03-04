import { cn } from '../../utils/helpers'

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode
}

export function Card({ className, children, ...props }: CardProps) {
  return (
    <div
      className={cn('bg-white rounded-2xl shadow-sm border border-gray-100 p-4', className)}
      {...props}
    >
      {children}
    </div>
  )
}

interface SectionHeaderProps {
  icon?: string
  title: string
  right?: React.ReactNode
  color?: string
}

export function SectionHeader({ icon, title, right, color = 'text-gray-800' }: SectionHeaderProps) {
  return (
    <div className="flex items-center justify-between mb-3">
      <h2 className={`font-semibold text-base flex items-center gap-2 ${color}`}>
        {icon && <span>{icon}</span>}
        {title}
      </h2>
      {right}
    </div>
  )
}
