import { InputHTMLAttributes } from "react";

interface InputTitleProps extends InputHTMLAttributes<HTMLInputElement> {
  title: string;
}

export function InputTitle({ title, ...props }: InputTitleProps) {
  return (
    <div className="space-y-2">
      <label className="block text-sm font-medium text-gray-800">{title}</label>
      <input
        className="w-full text-gray-900 border-gray-300 focus:ring focus:ring-blue-500 border rounded-md px-3 py-2"
        onClick={(e) => e.currentTarget.showPicker?.()}
        {...props}
      />
    </div>
  );
}
