import type { Arguments, CommandBuilder } from 'yargs';
import Transport from '@ledgerhq/hw-transport-node-hid';
import Speculos from '@ledgerhq/hw-transport-node-speculos';
import { Common } from 'hw-app-obsidian-common';

type Options = {
  path: string;
  payload: string;
  format: string;
  file: boolean | undefined;
  speculos: boolean;
  useBlock: boolean;
};

export const command: string = 'sign <path> <payload>';
export const desc: string = 'sign <payload> with the ledger using key <path>';

const formats : string[] = ['json', 'hex', 'base64', 'base64url', 'raw'];
const emptyExcl : any = {};
const formatIsExclusive : any = formats.reduce((excl, fmt) => { excl[fmt] = formats.filter(a=>a!=fmt); return excl; }, emptyExcl);

export const builder: CommandBuilder<Options, Options> = (yargs) =>
  yargs
    .options({
      json: {type: 'boolean'},
      hex: {type: 'boolean'},
      base64: {type: 'boolean'},
      base64url: {type: 'boolean'},
      raw: {type: 'boolean'},
      binary: {type: 'boolean'},
      format: {type: 'string'},
      file: {type: 'boolean'},
      speculos: {type: 'boolean'},
      useBlock: {type: 'boolean'},
      verbose: {type: 'boolean'},
    })
    .describe({
             json: "Input is JSON. Strips whitespace from the beginning and end of <payload>.",
             hex: "Input is hexadecimal. Non-hex characters at the end are ignored.",
             base64: "Input is base64",
             base64url: "Input is base64, with the url-friendly character set",
             raw: "Synonym for --binary",
             binary: "Take the input exactly as written; unencoded binary mode. Also appropriate for JSON where we need to include leading or trailing whitespace.",
             format: "Input format. The other format flags are equivalent to --format=<format>",
             file: "Treat <payload> as a filename and read the file rather than using the argument directly.",
             speculos: "Connect to a speculos instance instead of a real ledger; use --apdu 5555 when running speculos to enable.",
             useBlock: "Use block protocol",
             verbose: "Print verbose output of message transfer with ledger",
    })
    .conflicts(formatIsExclusive)
    .middleware([ function (argv) {
      for (const arg of formats) {
        if(argv[arg]) {
          argv.format = arg;
        }
      }
      if ( argv.format == 'raw' ) {
        argv.format = 'binary';
      }
    }])
    .default('format', 'hex')
    .default('speculos', false)
    .default('useBlock', false)
    .default('verbose', false)
    .positional('path', {type: 'string', demandOption: true, description: "Bip32 path to for the key to sign with."})
    .positional('payload', {type: 'string', demandOption: true, description: "Transaction/payload to sign, interpreted according to format and file options." })
    ;

export const handler = async (argv: Arguments<Options>): Promise<void> => {
  const { path, format, file, speculos, useBlock, verbose } = argv;
  let payloadString = argv.payload;

  if(file) {
    payloadString = await require('fs').promises.readFile(payloadString, 'binary');
  }
  let payload;
  if(format == 'json') {
    payload = Buffer.from(payloadString.trim(), 'binary');
  } else {
    payload = Buffer.from(payloadString, format as BufferEncoding);
  }

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

  console.log("Signing: ", payload);

  let res = await app.signTransaction(path, payload);

  process.stdout.write(res.signature+"\n");
  process.exit(0);
}

