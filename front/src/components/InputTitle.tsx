import { Flex } from "@radix-ui/themes";

interface InputTitleProps extends React.InputHTMLAttributes<HTMLInputElement> {
  title: string;
}

export function InputTitle({ title, ...props }: InputTitleProps) {
  return (
    <Flex direction="column" gap="2">
      <p>{title}</p>
      <input {...props} />
    </Flex>
  );
}
