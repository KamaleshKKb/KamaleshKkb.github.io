// src/components/Layout.tsx
import React from 'react';
import { Link, Outlet, useLocation } from 'react-router-dom';
import { LayoutDashboard, Package, ShoppingCart, LogOut } from 'lucide-react';

const Layout = () => {
  const location = useLocation();
  const menu = [
    { name: 'ড্যাশবোর্ড', path: '/dashboard', icon: <LayoutDashboard size={20} /> },
    { name: 'ইনভেন্টরি', path: '/inventory', icon: <Package size={20} /> },
    { name: 'বিক্রয় (POS)', path: '/pos', icon: <ShoppingCart size={20} /> },
  ];

  return (
    <div className="flex h-screen bg-gray-50 font-sans">
      <aside className="w-64 bg-slate-900 text-white flex flex-col">
        <div className="h-16 flex items-center justify-center border-b border-slate-800">
          <h1 className="text-xl font-bold tracking-wider text-blue-400">PHARMA<span className="text-white">CARE</span></h1>
        </div>
        <nav className="flex-1 py-6 px-4 space-y-2">
          {menu.map((item) => (
            <Link
              key={item.path}
              to={item.path}
              className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                location.pathname === item.path 
                  ? 'bg-blue-600 text-white' 
                  : 'text-slate-300 hover:bg-slate-800 hover:text-white'
              }`}
            >
              {item.icon}
              <span className="font-medium">{item.name}</span>
            </Link>
          ))}
        </nav>
        <div className="p-4 border-t border-slate-800">
          <button className="flex items-center gap-3 px-4 py-3 w-full text-slate-300 hover:bg-red-500 hover:text-white rounded-lg transition-colors">
            <LogOut size={20} />
            <span className="font-medium">লগআউট</span>
          </button>
        </div>
      </aside>
      <main className="flex-1 flex flex-col overflow-hidden">
        <header className="h-16 bg-white border-b border-gray-200 flex items-center justify-between px-6 shadow-sm">
          <h2 className="text-lg font-semibold text-gray-800">
            {menu.find(m => m.path === location.pathname)?.name || 'Dashboard'}
          </h2>
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center font-bold">A</div>
            <span className="text-sm font-medium text-gray-700">Admin</span>
          </div>
        </header>
        <div className="flex-1 overflow-auto bg-gray-50">
          <Outlet />
        </div>
      </main>
    </div>
  );
};

export default Layout;
