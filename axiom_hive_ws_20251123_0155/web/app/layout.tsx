import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Axiom Hive - Provably Safe AI',
  description: 'The definitive legal and safe AI model architecture',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className="bg-gray-50 min-h-screen">
        <header className="bg-white shadow-sm border-b">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center py-4">
              <div className="flex items-center">
                <h1 className="text-2xl font-bold text-gray-900">Axiom Hive</h1>
                <span className="ml-2 text-sm text-gray-500">v1.0.0</span>
              </div>
              <nav className="flex space-x-4">
                <a href="/" className="text-gray-700 hover:text-gray-900">Dashboard</a>
                <a href="/audit" className="text-gray-700 hover:text-gray-900">Audit Log</a>
                <a href="/docs" className="text-gray-700 hover:text-gray-900">Documentation</a>
              </nav>
            </div>
          </div>
        </header>
        <main>{children}</main>
      </body>
    </html>
  )
}
