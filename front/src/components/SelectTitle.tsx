import { Dispatch, SetStateAction } from "react";

interface CoinItem {
  name: string;
  address: string;
}

export function SelectTitle({
  title,
  items,
  defaultValue,
  setter,
}: {
  title: string;
  items: CoinItem[];
  defaultValue?: CoinItem;
  setter: Dispatch<SetStateAction<CoinItem>>;
}) {
  return (
    <div className="space-y-2">
      <label className="block text-sm font-medium text-gray-800">{title}</label>
      <select
        className="w-full text-gray-900 border-gray-300 focus:ring focus:ring-blue-500 border rounded-md px-3 py-2"
        defaultValue={defaultValue?.name ?? items[0]?.name}
        onChange={(e) => {
          const selectedCoin = items.find(
            (item) => item.name === e.target.value,
          );
          if (selectedCoin) {
            setter(selectedCoin);
          }
        }}
      >
        {items.map((item) => (
          <option
            key={item.name}
            value={item.name}
            className="bg-gray-100 text-gray-900"
          >
            {item.name}
          </option>
        ))}
      </select>
    </div>
  );
}
