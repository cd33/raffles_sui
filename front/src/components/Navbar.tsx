import { ConnectButton } from "@mysten/dapp-kit";
import { Box, Flex, Heading } from "@radix-ui/themes";

export function Navbar({ title }: { title: string }) {
  return (
    <Flex
      position="sticky"
      px="4"
      py="2"
      justify="between"
      style={{
        borderBottom: "1px solid var(--gray-a2)",
      }}
    >
      <Box>
        <Heading>{title}</Heading>
      </Box>

      <Box>
        <ConnectButton />
      </Box>
    </Flex>
  );
}
