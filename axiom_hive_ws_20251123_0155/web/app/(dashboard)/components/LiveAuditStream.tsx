'use client'

import { useState, useEffect } from 'react'

interface AuditEntry {
  id: string
  timestamp: string
  service: string
  status: 'safe' | 'warning' | 'danger'
  message: string
}

export function LiveAuditStream() {
  const [auditEntries, setAuditEntries] = useState<AuditEntry[]>([])

  // Mock data for demonstration
  useEffect(() => {
    const mockEntries: AuditEntry[] = [
      {
        id: '1',
        timestamp: new Date().toISOString(),
        service: 'Legal Guardian',
        status: 'safe',
        message: 'Request compliant with ASL-1.0'
      },
      {
        id: '2',
        timestamp: new Date(Date.now() - 2000).toISOString(),
        service: 'Safety Guardian',
        status: 'safe',
        message: 'No toxicity detected'
      },
      {
        id: '3',
        timestamp: new Date(Date.now() - 4000).toISOString(),
        service: 'Drone Fleet',
        status: 'safe',
        message: 'Response generated successfully'
      }
    ]
    setAuditEntries(mockEntries)
  }, [])

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'safe': return 'axiom-status-safe'
      case 'warning': return 'axiom-status-warning'
      case 'danger': return 'axiom-status-danger'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold text-gray-900">Live Audit Stream</h2>
        <div className="flex items-center space-x-2">
          <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
          <span className="text-sm text-gray-600">Live</span>
        </div>
      </div>

      <div className="space-y-3 max-h-96 overflow-y-auto">
        {auditEntries.map((entry: AuditEntry) => (
          <div key={entry.id} className="flex items-start space-x-3 p-3 bg-gray-50 rounded-lg">
            <div className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(entry.status)}`}>
              {entry.service}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm text-gray-900">{entry.message}</p>
              <p className="text-xs text-gray-500">
                {new Date(entry.timestamp).toLocaleTimeString()}
              </p>
            </div>
            <div className={`w-3 h-3 rounded-full ${
              entry.status === 'safe' ? 'bg-green-500' :
              entry.status === 'warning' ? 'bg-yellow-500' : 'bg-red-500'
            }`}></div>
          </div>
        ))}
      </div>

      <div className="mt-4 pt-4 border-t border-gray-200">
        <div className="flex items-center justify-between text-sm text-gray-600">
          <span>Real-time verification of all AI interactions</span>
          <button className="text-blue-600 hover:text-blue-800 font-medium">
            Export Audit Log
          </button>
        </div>
      </div>
    </div>
  )
}
