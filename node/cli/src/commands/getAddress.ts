import type { Arguments, CommandBuilder } from 'yargs';
import Transport from '@ledgerhq/hw-transport-node-hid';
import Speculos from '@ledgerhq/hw-transport-node-speculos';
import { Common } from 'hw-app-obsidian-common';

type Options = {
  path: string;
  speculos: boolean;
  useBlock: boolean;
  json: boolean;
};

export const command: string = 'getAddress <path>';
export const desc: string = 'Get address for <path> from ledger';

export const builder: CommandBuilder<Options, Options> = (yargs) =>
  yargs
    .options({
      speculos: {type: 'boolean'},
      useBlock: {type: 'boolean'},
      json: {type: 'boolean'},
      verbose: {type: 'boolean'},
    })
    .describe({
      speculos: "Connect to a speculos instance instead of a real ledger; use --apdu 5555 when running speculos to enable.",
      useBlock: "Use block protocol",
      json: "Output all fields from getAddress in json format",
      verbose: "Print verbose output of message transfer with ledger",
    })
    .default('speculos', false)
    .default('useBlock', false)
    .default('json', false)
    .default('verbose', false)
    .positional('path', {type: 'string', demandOption: true, description: "Bip32 path to for the public key to provide."});

export const handler = async (argv: Arguments<Options>): Promise<void> => {
  const { path, speculos, useBlock, json, verbose } = argv;

  let transport;
  if (speculos) {
    transport = await Speculos.open({apduPort: 5555});
  } else {
    transport = await Transport.open(undefined);
  }

  let app = new Common(transport, "", "", verbose === true);
  if(useBlock) {
    app.sendChunks = app.sendWithBlocks;
  }

  let res = await app.getPublicKey(path);

  if(json) {
    process.stdout.write(JSON.stringify(res, null, 2));
    process.exit(0);
  }
  process.stdout.write(res.publicKey + "\n");
  process.exit(0);
}

