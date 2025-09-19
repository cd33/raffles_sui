import React from "react";

export function SelectTitle({
  title,
  items,
  defaultValue,
  setter,
}: {
  title: string;
  items: string[];
  defaultValue?: string;
  setter: React.Dispatch<React.SetStateAction<string>>;
}) {
  return (
    <div className="space-y-2">
      <label className="block text-sm font-medium text-gray-800">{title}</label>
      <select
        className="w-full text-gray-900 border-gray-300 focus:ring focus:ring-blue-500 border rounded-md px-3 py-2"
        defaultValue={defaultValue ?? items[0]}
        onChange={(e) => setter(e.target.value)}
      >
        {items.map((item) => (
          <option key={item} value={item} className="bg-gray-100 text-gray-900">
            {item}
          </option>
        ))}
      </select>
    </div>
  );
}
