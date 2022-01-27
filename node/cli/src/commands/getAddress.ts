import type { Arguments, CommandBuilder } from 'yargs';
import Transport from '@ledgerhq/hw-transport-node-hid';
import Speculos from '@ledgerhq/hw-transport-node-speculos';
import { Common } from 'hw-app-obsidian-common';

type Options = {
  path: string;
  speculos: boolean;
};

export const command: string = 'getAddress <path>';
export const desc: string = 'Get address for <path> from ledger';

export const builder: CommandBuilder<Options, Options> = (yargs) =>
  yargs
    .options({ speculos: {type: 'boolean'} })
    .describe({
      speculos: "Connect to a speculos instance instead of a real ledger; use --apdu 5555 when running speculos to enable."
    })
    .default('speculos', false)
    .positional('path', {type: 'string', demandOption: true, description: "Bip32 path to for the public key to provide."});

export const handler = async (argv: Arguments<Options>): Promise<void> => {
  const { path, speculos } = argv;

  let transport;
  if (speculos) {
    transport = await Speculos.open({apduPort: 5555});
  } else {
    transport = await Transport.open(undefined);
  }

  let app = new Common(transport, "");

  let res = await app.getPublicKey(path);

  process.stdout.write(res.publicKey + "\n");
  process.exit(0);
}

