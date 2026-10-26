// src/pages/Dashboard.tsx
import React from 'react';
import { Package, TrendingUp, AlertTriangle, Users } from 'lucide-react';

const Dashboard = () => {
  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Pharmacy Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
          <div>
            <p className="text-sm text-gray-500 font-medium">আজকের বিক্রি</p>
            <h3 className="text-2xl font-bold text-gray-800">৳ ২৪,৫০০</h3>
          </div>
          <div className="p-3 bg-blue-50 text-blue-600 rounded-lg"><TrendingUp size={24} /></div>
        </div>
        <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
          <div>
            <p className="text-sm text-gray-500 font-medium">মোট ঔষধ</p>
            <h3 className="text-2xl font-bold text-gray-800">১,২৪৫</h3>
          </div>
          <div className="p-3 bg-green-50 text-green-600 rounded-lg"><Package size={24} /></div>
        </div>
        <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
          <div>
            <p className="text-sm text-gray-500 font-medium">স্টক শেষ (Low)</p>
            <h3 className="text-2xl font-bold text-red-600">১২</h3>
          </div>
          <div className="p-3 bg-red-50 text-red-600 rounded-lg"><AlertTriangle size={24} /></div>
        </div>
        <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
          <div>
            <p className="text-sm text-gray-500 font-medium">কাস্টমার</p>
            <h3 className="text-2xl font-bold text-gray-800">৮৪২</h3>
          </div>
          <div className="p-3 bg-purple-50 text-purple-600 rounded-lg"><Users size={24} /></div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
