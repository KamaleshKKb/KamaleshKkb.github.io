import React from 'react';

const Index = () => {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-blue-50 text-center p-4">
      <h1 className="text-4xl font-bold text-blue-600 mb-4">
        স্বাগতম! (Welcome!)
      </h1>
      <p className="text-lg text-gray-700 mb-8">
        আপনার ওয়েবসাইটটি এখন সফলভাবে লাইভ হয়েছে। 🎉
      </p>
      <button className="px-6 py-3 bg-blue-600 text-white rounded-lg shadow-md hover:bg-blue-700 transition">
        শুরু করুন
      </button>
    </div>
  );
};

export default Index;
