const ADDRESS_0x = exports.ADDRESS_0x = '0x0000000000000000000000000000000000000000'
const BYTES32_EMPTY = exports.BYTES32_EMPTY = '0x0000000000000000000000000000000000000000000000000000000000000000'

const randomBytes = exports.randomBytes = (len) => {
    var str = ''
    while (str.length < len) {
        str += Math.random().toString(36).substring(0, 12).substring(2)
    }
    return str.substring(0, len)
}
