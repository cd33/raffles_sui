import { Flex, Select } from "@radix-ui/themes";

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
    <Flex direction="column" gap="2">
      <p>{title}</p>
      <Select.Root
        defaultValue={defaultValue ?? items[0]}
        onValueChange={setter}
      >
        <Select.Trigger />
        <Select.Content>
          <Select.Group>
            {items.map((item) => (
              <Select.Item key={item} value={item}>
                {item}
              </Select.Item>
            ))}
          </Select.Group>
        </Select.Content>
      </Select.Root>
    </Flex>
  );
}
